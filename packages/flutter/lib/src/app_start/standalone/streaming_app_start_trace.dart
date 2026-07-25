// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_data.dart';
import 'app_start_trace.dart';

@internal
final class StreamingAppStartTrace implements AppStartTrace {
  final Hub _hub;
  final AppStartData _data;
  final IdleRecordingSentrySpanV2 _root;
  final RecordingSentrySpanV2 _firstFrameRenderSpan;
  final String Function() _startScreenNameProvider;

  DateTime? _endTimestamp;
  AppStartTraceState _state = AppStartTraceState.open;

  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartData data,
    required IdleRecordingSentrySpanV2 root,
    required RecordingSentrySpanV2 firstFrameRenderSpan,
    required String Function() startScreenNameProvider,
  })  : _hub = hub,
        _data = data,
        _root = root,
        _firstFrameRenderSpan = firstFrameRenderSpan,
        _startScreenNameProvider = startScreenNameProvider;

  static StreamingAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required String Function() startScreenNameProvider,
  }) {
    IdleRecordingSentrySpanV2? createdRoot;
    final createdChildren = <RecordingSentrySpanV2>[];
    try {
      final root = hub.startIdleSpan(
        standaloneAppStartRootName,
        bindToHub: false,
        idleTimeout: standaloneAppStartIdleTimeout,
        finalTimeout: standaloneAppStartFinalTimeout,
        trimIdleSpanEndTimestamp: true,
        startTimestamp: data.processStartTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp: SentryAttribute.string(
            SentrySpanOperations.appStart,
          ),
          SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoAppStart,
          ),
          SemanticAttributesConstants.appVitalsStartType:
              SentryAttribute.string(data.type.name),
        },
      );
      if (root is! IdleRecordingSentrySpanV2) return null;
      createdRoot = root;

      final firstFrameRenderSpan = hub.startInactiveSpan(
        appStartFirstFrameRenderDescription,
        parentSpan: root,
        startTimestamp: data.sentrySetupTimestamp,
        attributes: _childAttributes(
          data,
          SentrySpanOperations.appStartFirstFrameRender,
        ),
      );
      if (firstFrameRenderSpan is! RecordingSentrySpanV2) {
        _finishProvisionalSpans(root: createdRoot);
        return null;
      }
      createdChildren.add(firstFrameRenderSpan);

      final trace = StreamingAppStartTrace._(
        hub: hub,
        data: data,
        root: root,
        firstFrameRenderSpan: firstFrameRenderSpan,
        startScreenNameProvider: startScreenNameProvider,
      );
      for (final phase in data.phases) {
        final child = hub.startInactiveSpan(
          phase.description,
          parentSpan: root,
          startTimestamp: phase.startTimestamp,
          attributes: _childAttributes(data, phase.kind.operation),
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
      _finishProvisionalSpans(
        root: createdRoot,
        children: createdChildren,
      );
      internalLogger.error(
        'Failed to create streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Map<String, SentryAttribute> _childAttributes(
    AppStartData data,
    String operation,
  ) =>
      {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(operation),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
          data.type.name,
        ),
      };

  static void _finishProvisionalSpans({
    IdleRecordingSentrySpanV2? root,
    Iterable<RecordingSentrySpanV2> children = const [],
  }) {
    for (final child in children) {
      if (!child.isEnded) {
        child.end();
      }
    }
    root?.end();
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
      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        SentryAttribute.string(_startScreenNameProvider()),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(standaloneAppStartRootName),
      );

      final endTimestamp = _endTimestamp;
      final deadlineExceeded = _root.status == SentrySpanStatusV2.error &&
          _root.attributes[SemanticAttributesConstants.sentryStatusMessage]
                  ?.value ==
              SentrySpanStatusMessages.deadlineExceeded;
      if (endTimestamp != null && !deadlineExceeded) {
        final duration =
            _data.durationUntil(endTimestamp).inMilliseconds.toDouble();
        final value = SentryAttribute.double(duration);
        _root.setAttribute(
          SemanticAttributesConstants.appVitalsStartValue,
          value,
        );
        _root.setAttribute(
          _data.type == AppStartType.cold
              ? SemanticAttributesConstants.appVitalsStartColdValue
              : SemanticAttributesConstants.appVitalsStartWarmValue,
          value,
        );
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
  void close() {
    if (_state.isTerminal) return;
    _state = AppStartTraceState.closed;
    _root.end();
  }
}
