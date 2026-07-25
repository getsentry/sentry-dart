// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_timing.dart';
import 'app_start_trace.dart';
import 'app_start_vitals.dart';

@internal
final class StreamingAppStartTrace implements AppStartTrace {
  final Hub _hub;
  final AppStartTiming _timing;
  final IdleRecordingSentrySpanV2 _root;
  final RecordingSentrySpanV2 _firstFrameRenderSpan;
  final String Function() _startScreenNameProvider;

  DateTime? _endTimestamp;
  AppStartTraceState _state = AppStartTraceState.open;

  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartTiming timing,
    required IdleRecordingSentrySpanV2 root,
    required RecordingSentrySpanV2 firstFrameRenderSpan,
    required String Function() startScreenNameProvider,
  })  : _hub = hub,
        _timing = timing,
        _root = root,
        _firstFrameRenderSpan = firstFrameRenderSpan,
        _startScreenNameProvider = startScreenNameProvider;

  /// Opens the standalone root and its breakdown children.
  ///
  /// Returns `null` when the app start must not be reported: a root or
  /// first-frame span the SDK did not record, or a failure while building the
  /// children. Anything already created is flushed, so no span outlives a
  /// failed creation.
  static StreamingAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartTiming timing,
    required String Function() startScreenNameProvider,
  }) {
    // Held outside the try so a partially built trace can still be flushed.
    IdleRecordingSentrySpanV2? root;
    final createdChildren = <RecordingSentrySpanV2>[];
    try {
      final createdRoot = hub.startIdleSpan(
        standaloneAppStartRootName,
        bindToHub: false,
        idleTimeout: standaloneAppStartIdleTimeout,
        finalTimeout: standaloneAppStartFinalTimeout,
        trimIdleSpanEndTimestamp: true,
        startTimestamp: timing.processStartTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp: SentryAttribute.string(
            SentrySpanOperations.appStart,
          ),
          SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoAppStart,
          ),
          SemanticAttributesConstants.appVitalsStartType:
              SentryAttribute.string(timing.type.name),
        },
      );
      if (createdRoot is! IdleRecordingSentrySpanV2) return null;
      root = createdRoot;

      final firstFrameRenderSpan = hub.startInactiveSpan(
        appStartFirstFrameRenderDescription,
        parentSpan: root,
        startTimestamp: timing.sentrySetupTimestamp,
        attributes: _childAttributes(
          timing,
          SentrySpanOperations.appStartFirstFrameRender,
        ),
      );
      if (firstFrameRenderSpan is! RecordingSentrySpanV2) {
        return _abort(root, reason: 'first-frame span is not recording');
      }
      createdChildren.add(firstFrameRenderSpan);

      final trace = StreamingAppStartTrace._(
        hub: hub,
        timing: timing,
        root: root,
        firstFrameRenderSpan: firstFrameRenderSpan,
        startScreenNameProvider: startScreenNameProvider,
      );
      for (final phase in timing.phases) {
        final child = hub.startInactiveSpan(
          phase.description,
          parentSpan: root,
          startTimestamp: phase.startTimestamp,
          attributes: _childAttributes(timing, phase.kind.operation),
        );
        if (child is RecordingSentrySpanV2) {
          createdChildren.add(child);
        }
        child.end(endTimestamp: phase.endTimestamp);
      }
      hub.options.lifecycleRegistry.registerCallback<OnProcessSpan>(
        trace._processSpan,
      );
      return trace;
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to create streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return root == null ? null : _abort(root, children: createdChildren);
    }
  }

  static Map<String, SentryAttribute> _childAttributes(
    AppStartTiming timing,
    String operation,
  ) =>
      {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(operation),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
          timing.type.name,
        ),
      };

  /// Flushes everything created so far and reports no trace.
  ///
  /// Children are ended here rather than left to the root's own teardown,
  /// which force-ends descendants with timestamps derived for a trace that is
  /// being reported — not one being abandoned.
  static StreamingAppStartTrace? _abort(
    IdleRecordingSentrySpanV2 root, {
    Iterable<RecordingSentrySpanV2> children = const [],
    String? reason,
  }) {
    if (reason != null) {
      internalLogger.info('Skipping streaming standalone app start: $reason');
    }
    for (final child in children) {
      if (!child.isEnded) {
        child.end();
      }
    }
    root.end();
    return null;
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {
    if (_state.isTerminal || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
    _firstFrameRenderSpan.end(endTimestamp: _endTimestamp);
  }

  void _processSpan(OnProcessSpan event) {
    if (!identical(event.span, _root) ||
        _state == AppStartTraceState.completed) {
      return;
    }
    try {
      final vitals = AppStartVitals.resolve(
        timing: _timing,
        screen: _startScreenNameProvider(),
        endTimestamp: _endTimestamp,
        deadlineExceeded: _root.deadlineExceeded,
      );

      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        SentryAttribute.string(vitals.screen),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(standaloneAppStartRootName),
      );

      final duration = vitals.duration;
      if (duration != null) {
        final value =
            SentryAttribute.double(duration.inMilliseconds.toDouble());
        _root.setAttribute(
          SemanticAttributesConstants.appVitalsStartValue,
          value,
        );
        _root.setAttribute(vitals.durationAttributeKey, value);
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to enrich streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _state = AppStartTraceState.completed;
      _hub.options.lifecycleRegistry.removeCallback<OnProcessSpan>(
        _processSpan,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_state.isTerminal) return;
    _state = AppStartTraceState.closed;
    _root.end();
  }
}
