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

  final _StreamingAppStartExtensionLifecycle _extensionLifecycle;
  late final SdkLifecycleCallback<OnProcessSpan> _processCallback;
  DateTime? _endTimestamp;
  bool _completed = false;
  bool _closed = false;

  bool get _isClosedOrCompleted => _closed || _completed;

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
        _startScreenNameProvider = startScreenNameProvider,
        _extensionLifecycle = _StreamingAppStartExtensionLifecycle(
          hub: hub,
          root: root,
        );

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
      trace._processCallback = trace._processSpan;
      for (final phase in data.phases) {
        final child = hub.startInactiveSpan(
          phase.description,
          parentSpan: root,
          startTimestamp: phase.startTimestamp,
          attributes: _childAttributes(data, phase.operation),
        );
        if (child is RecordingSentrySpanV2) {
          createdChildren.add(child);
        }
        child.end(endTimestamp: phase.endTimestamp);
      }
      hub.options.lifecycleRegistry.registerCallback<OnProcessSpan>(
        trace._processCallback,
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
  bool tryExtend(DateTime startTimestamp) {
    if (_isClosedOrCompleted || _firstFrameRenderSpan.isEnded) {
      return false;
    }

    return _extensionLifecycle.tryStart(startTimestamp);
  }

  @override
  ISentrySpan? get extendedSpan => null;

  @override
  SentrySpanV2? get extendedSpanV2 => _extensionLifecycle.activeSpan;

  @override
  Future<void> finishExtended(DateTime endTimestamp) {
    if (_isClosedOrCompleted) {
      return Future<void>.value();
    }

    return _extensionLifecycle.finish(endTimestamp);
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {
    if (_isClosedOrCompleted) return;
    _firstFrameRenderSpan.end(endTimestamp: endTimestamp.toUtc());
  }

  @override
  void finish(DateTime endTimestamp) {
    if (_isClosedOrCompleted || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
  }

  void _processSpan(OnProcessSpan event) {
    if (!identical(event.span, _root) || _completed) return;
    try {
      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartType,
        SentryAttribute.string(_data.type.name),
      );
      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        SentryAttribute.string(_startScreenNameProvider()),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(standaloneAppStartRootName),
      );

      final endTimestamp = _endTimestamp;
      final extension = _extensionLifecycle.completionSnapshot;
      if (endTimestamp != null &&
          extension.completed &&
          !_hasExceededDeadline(_root)) {
        final measurementEnd = resolveAppStartMeasurementEnd(
          endTimestamp,
          extension.endTimestamp,
        );
        final duration =
            _data.durationUntil(measurementEnd).inMilliseconds.toDouble();
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
      _completed = true;
      _hub.options.lifecycleRegistry.removeCallback<OnProcessSpan>(
        _processCallback,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_isClosedOrCompleted) return;
    _closed = true;
    try {
      await _extensionLifecycle.close();
    } finally {
      _root.end();
    }
  }
}

final class _StreamingAppStartExtensionLifecycle {
  final Hub _hub;
  final IdleRecordingSentrySpanV2 _root;

  late final SdkLifecycleCallback<OnSpanEndV2> _spanEndCallback;
  RecordingSentrySpanV2? _span;
  Future<void>? _finishFuture;
  DateTime? _endTimestamp;
  bool _closed = false;

  _StreamingAppStartExtensionLifecycle({
    required Hub hub,
    required IdleRecordingSentrySpanV2 root,
  })  : _hub = hub,
        _root = root {
    _spanEndCallback = _handleSpanEnd;
  }

  bool tryStart(DateTime startTimestamp) {
    if (_closed || _span != null) return false;

    final span = _hub.startInactiveSpan(
      standaloneExtendedAppStartName,
      parentSpan: _root,
      startTimestamp: startTimestamp.toUtc(),
      attributes: {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(
          SentrySpanOperations.appStartExtended,
        ),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
      },
    );
    if (span is! RecordingSentrySpanV2) return false;

    _span = span;
    _hub.options.lifecycleRegistry.registerCallback<OnSpanEndV2>(
      _spanEndCallback,
    );
    return true;
  }

  SentrySpanV2? get activeSpan {
    final span = _span;
    return span == null || span.isEnded ? null : span;
  }

  ({bool completed, DateTime? endTimestamp}) get completionSnapshot => (
        completed: _span == null || _endTimestamp != null,
        endTimestamp: _endTimestamp,
      );

  Future<void> finish(DateTime endTimestamp) {
    if (_closed || _span == null) return Future<void>.value();
    return _finishFuture ??= _finishSpan(endTimestamp.toUtc());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    final finishFuture = _finishFuture;
    if (finishFuture != null) {
      await finishFuture;
      return;
    }

    final span = _span;
    if (span != null && _endTimestamp == null) {
      await _finishSpan(span.endTimestamp);
    }
  }

  // Handle callers ending the span directly instead of using
  // finishExtendedAppStart().
  void _handleSpanEnd(OnSpanEndV2 event) {
    final span = _span;
    if (span == null || !identical(event.span, span) || _endTimestamp != null) {
      return;
    }

    final endTimestamp = span.endTimestamp;
    if (endTimestamp == null) return;

    if (_hasExceededDeadline(_root)) {
      span.status = SentrySpanStatusV2.error;
      span.setAttribute(
        SemanticAttributesConstants.sentryStatusMessage,
        SentryAttribute.string(SentrySpanStatusMessages.deadlineExceeded),
      );
    } else {
      span.status = SentrySpanStatusV2.ok;
    }

    _endTimestamp = endTimestamp;
    _removeSpanEndCallback();
  }

  Future<void> _finishSpan(DateTime? endTimestamp) async {
    if (_endTimestamp != null) return;
    final span = _span;
    try {
      final timestamp =
          (span?.endTimestamp ?? endTimestamp ?? _hub.options.clock()).toUtc();
      _endTimestamp = timestamp;
      if (span == null) return;

      span.status = SentrySpanStatusV2.ok;
      if (!span.isEnded) {
        span.end(endTimestamp: timestamp);
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to finish streaming extended app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _removeSpanEndCallback();
    }
  }

  void _removeSpanEndCallback() {
    _hub.options.lifecycleRegistry.removeCallback<OnSpanEndV2>(
      _spanEndCallback,
    );
  }
}

bool _hasExceededDeadline(IdleRecordingSentrySpanV2 root) =>
    root.status == SentrySpanStatusV2.error &&
    root.attributes[SemanticAttributesConstants.sentryStatusMessage]?.value ==
        SentrySpanStatusMessages.deadlineExceeded;
