// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_constants.dart';
import 'app_start_data.dart';
import 'app_start_trace.dart';

@internal
final class StreamingAppStartTrace implements AppStartTrace {
  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartData data,
    required IdleRecordingSentrySpanV2 root,
    required RecordingSentrySpanV2 firstFrameBarrier,
    required void Function() onCompleted,
    required String Function() appStartScreenNameProvider,
  })  : _hub = hub,
        _data = data,
        _root = root,
        _firstFrameBarrier = firstFrameBarrier,
        _onCompleted = onCompleted,
        _appStartScreenNameProvider = appStartScreenNameProvider;

  final Hub _hub;
  final AppStartData _data;
  final IdleRecordingSentrySpanV2 _root;
  final RecordingSentrySpanV2 _firstFrameBarrier;
  final void Function() _onCompleted;
  final String Function() _appStartScreenNameProvider;

  late final SdkLifecycleCallback<OnProcessSpan> _processCallback;
  DateTime? _naturalEnd;
  bool _completed = false;
  bool _closed = false;

  static StreamingAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required void Function() onCompleted,
    required String Function() appStartScreenNameProvider,
  }) {
    IdleRecordingSentrySpanV2? root;
    StreamingAppStartTrace? trace;
    try {
      final createdRoot = hub.startIdleSpan(
        appStartRootName,
        setAsActive: false,
        idleTimeout: appStartIdleTimeout,
        finalTimeout: appStartFinalTimeout,
        trimIdleSpanEndTimestamp: true,
        startTimestamp: data.processStartTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp:
              SentryAttribute.string(SentrySpanOperations.appStart),
          SemanticAttributesConstants.sentryOrigin:
              SentryAttribute.string(SentryTraceOrigins.autoAppStart),
          SemanticAttributesConstants.appVitalsStartType:
              SentryAttribute.string(data.type.name),
        },
      );
      if (createdRoot is! IdleRecordingSentrySpanV2) return null;
      root = createdRoot;

      final barrier = hub.startInactiveSpan(
        appStartFirstFrameRenderDescription,
        parentSpan: root,
        startTimestamp: data.sentrySetupTimestamp,
        attributes: _childAttributes(
          data,
          SentrySpanOperations.appStartFirstFrameRender,
        ),
      );
      if (barrier is! RecordingSentrySpanV2) {
        unawaited(root.cancel());
        return null;
      }

      trace = StreamingAppStartTrace._(
        hub: hub,
        data: data,
        root: root,
        firstFrameBarrier: barrier,
        onCompleted: onCompleted,
        appStartScreenNameProvider: appStartScreenNameProvider,
      );
      trace._processCallback = trace._processSpan;
      trace._createCompletedBreakdownSpans();
      hub.options.lifecycleRegistry
          .registerCallback<OnProcessSpan>(trace._processCallback);
      return trace;
    } catch (error, stackTrace) {
      if (trace != null) {
        unawaited(trace.close());
      } else if (root != null) {
        unawaited(root.cancel());
      }
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
        SemanticAttributesConstants.sentryOrigin:
            SentryAttribute.string(SentryTraceOrigins.autoAppStart),
        SemanticAttributesConstants.appVitalsStartType:
            SentryAttribute.string(data.type.name),
      };

  void _createCompletedBreakdownSpans() {
    for (final phase in _data.completedBreakdownPhases) {
      _finishChild(
        operation: phase.operation,
        description: phase.description,
        startTimestamp: phase.startTimestamp,
        endTimestamp: phase.endTimestamp,
      );
    }
  }

  void _finishChild({
    required String operation,
    required String description,
    required DateTime startTimestamp,
    required DateTime endTimestamp,
  }) {
    _hub
        .startInactiveSpan(
          description,
          parentSpan: _root,
          startTimestamp: startTimestamp,
          attributes: _childAttributes(_data, operation),
        )
        .end(endTimestamp: endTimestamp);
  }

  @override
  void recordNaturalEnd(DateTime endTimestamp) {
    if (_closed || _completed || _naturalEnd != null) return;
    _naturalEnd = endTimestamp.toUtc();
    _firstFrameBarrier.end(endTimestamp: _naturalEnd);
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
        SentryAttribute.string(_appStartScreenNameProvider()),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(appStartRootName),
      );

      final naturalEnd = _naturalEnd;
      final deadlineExceeded = _root.status == SentrySpanStatusV2.error &&
          _root.attributes[SemanticAttributesConstants.sentryStatusMessage]
                  ?.value ==
              SentrySpanStatusMessages.deadlineExceeded;
      if (naturalEnd != null && !deadlineExceeded) {
        final duration = appStartDuration(
          _data.processStartTimestamp,
          naturalEnd,
        ).inMilliseconds.toDouble();
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
      try {
        _hub.options.lifecycleRegistry
            .removeCallback<OnProcessSpan>(_processCallback);
      } finally {
        try {
          _onCompleted();
        } catch (error, stackTrace) {
          internalLogger.error(
            'Failed to complete streaming standalone app start',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed || _completed) return;
    _closed = true;
    _hub.options.lifecycleRegistry
        .removeCallback<OnProcessSpan>(_processCallback);
    await _root.cancel();
  }
}
