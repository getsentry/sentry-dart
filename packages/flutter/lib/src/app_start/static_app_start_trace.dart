// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_constants.dart';
import 'app_start_data.dart';
import 'app_start_trace.dart';

@internal
final class StaticAppStartTrace implements AppStartTrace {
  StaticAppStartTrace._({
    required AppStartData data,
    required SentryTracer root,
    required ISentrySpan firstFrameBarrier,
    required void Function() onCompleted,
    required String Function() initialScreenName,
  })  : _data = data,
        _root = root,
        _firstFrameBarrier = firstFrameBarrier,
        _onCompleted = onCompleted,
        _initialScreenName = initialScreenName;

  final AppStartData _data;
  final SentryTracer _root;
  final ISentrySpan _firstFrameBarrier;
  final void Function() _onCompleted;
  final String Function() _initialScreenName;

  DateTime? _naturalEnd;
  bool _completed = false;
  bool _closed = false;

  static StaticAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required void Function() onCompleted,
    required String Function() initialScreenName,
  }) {
    StaticAppStartTrace? trace;
    SentryTracer? root;
    try {
      final createdAt = hub.options.clock();
      final createdRoot = hub.startTransactionWithContext(
        SentryTransactionContext(
          appStartRootName,
          SentrySpanOperations.appStart,
          origin: SentryTraceOrigins.autoAppStart,
        ),
        startTimestamp: data.processStartTimestamp,
        waitForChildren: true,
        autoFinishAfter: appStartIdleTimeout,
        bindToScope: false,
        trimEnd: true,
        onFinish: (_) => trace?._enrichAndComplete(),
      );
      if (createdRoot is! SentryTracer ||
          createdRoot.samplingDecision?.sampled != true) {
        if (createdRoot is SentryTracer) {
          createdRoot.abandon();
        }
        return null;
      }
      root = createdRoot;

      final firstFrameBarrier = root.startChild(
        SentrySpanOperations.appStart,
        description: appStartFirstFrameRenderDescription,
        startTimestamp: data.sentrySetupTimestamp,
      );
      if (firstFrameBarrier.samplingDecision?.sampled != true) {
        root.abandon();
        return null;
      }

      trace = StaticAppStartTrace._(
        data: data,
        root: root,
        firstFrameBarrier: firstFrameBarrier,
        onCompleted: onCompleted,
        initialScreenName: initialScreenName,
      );
      trace._createCompletedBreakdownSpans();

      if (!root.tryScheduleFinalTimeout(
        createdAt.add(appStartFinalTimeout),
      )) {
        trace.close();
        return null;
      }
      return trace;
    } catch (error, stackTrace) {
      if (trace != null) {
        trace.close();
      } else if (root != null) {
        root.abandon();
      }
      internalLogger.error(
        'Failed to create static standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

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
    final child = _root.startChild(
      operation,
      description: description,
      startTimestamp: startTimestamp,
    )..origin = SentryTraceOrigins.autoAppStart;
    _finish(child, endTimestamp: endTimestamp);
  }

  @override
  void recordNaturalEnd(DateTime endTimestamp) {
    if (_closed || _completed || _naturalEnd != null) return;
    _naturalEnd = endTimestamp.toUtc();
    _finish(_firstFrameBarrier, endTimestamp: _naturalEnd);
    _root.scheduleFinish();
  }

  void _enrichAndComplete() {
    if (_completed) return;
    try {
      final type = _data.type.name;
      _root.setData('app_start_type', type);
      _root.setData(SemanticAttributesConstants.appVitalsStartType, type);
      _root.setData(
        SemanticAttributesConstants.appVitalsStartScreen,
        _initialScreenName(),
      );

      final naturalEnd = _naturalEnd;
      if (naturalEnd != null && _root.status != SpanStatus.deadlineExceeded()) {
        final duration = appStartDuration(
          _data.processStartTimestamp,
          naturalEnd,
        );
        final measurement = _data.type == AppStartType.cold
            ? SentryMeasurement.coldAppStart(duration)
            : SentryMeasurement.warmAppStart(duration);
        _root.setMeasurement(
          measurement.name,
          measurement.value,
          unit: measurement.unit,
        );
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to enrich static standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _completed = true;
      try {
        _onCompleted();
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to complete static standalone app start',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _finish(ISentrySpan span, {DateTime? endTimestamp}) {
    unawaited(
      span.finish(endTimestamp: endTimestamp).catchError(
        (Object error, StackTrace stackTrace) {
          internalLogger.error(
            'Failed to finish static app-start span',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  @override
  void close() {
    if (_closed || _completed) return;
    _closed = true;
    _root.abandon();
  }
}
