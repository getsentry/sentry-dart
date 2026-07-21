// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_data.dart';
import 'app_start_trace.dart';

@internal
final class StaticAppStartTrace implements AppStartTrace {
  final AppStartData _data;
  final SentryTracer _root;
  final ISentrySpan _firstFrameBarrier;
  final String Function() _startScreenNameProvider;

  DateTime? _endTimestamp;
  bool _completed = false;
  bool _closed = false;

  StaticAppStartTrace._({
    required AppStartData data,
    required SentryTracer root,
    required ISentrySpan firstFrameBarrier,
    required String Function() startScreenNameProvider,
  })  : _data = data,
        _root = root,
        _firstFrameBarrier = firstFrameBarrier,
        _startScreenNameProvider = startScreenNameProvider;

  static StaticAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required String Function() startScreenNameProvider,
  }) {
    StaticAppStartTrace? trace;
    SentryTracer? createdRoot;
    final provisionalChildren = <ISentrySpan>[];
    try {
      final createdAt = hub.options.clock();
      final root = hub.startTransactionWithContext(
        SentryTransactionContext(
          standaloneAppStartRootName,
          SentrySpanOperations.appStart,
          origin: SentryTraceOrigins.autoAppStart,
        ),
        startTimestamp: data.processStartTimestamp,
        waitForChildren: true,
        autoFinishAfter: standaloneAppStartIdleTimeout,
        bindToScope: false,
        trimEnd: true,
        onFinish: (_) => trace?._enrichAndComplete(),
      );
      if (root is! SentryTracer) return null;
      createdRoot = root;
      if (root.samplingDecision?.sampled != true) {
        unawaited(_flushTrace(root: root));
        return null;
      }

      final firstFrameBarrier = root.startChild(
        SentrySpanOperations.appStartFirstFrameRender,
        description: appStartFirstFrameRenderDescription,
        startTimestamp: data.sentrySetupTimestamp,
      )..origin = SentryTraceOrigins.autoAppStart;
      if (firstFrameBarrier is! NoOpSentrySpan) {
        provisionalChildren.add(firstFrameBarrier);
      }
      if (firstFrameBarrier.samplingDecision?.sampled != true) {
        unawaited(_flushTrace(root: root, children: provisionalChildren));
        return null;
      }

      trace = StaticAppStartTrace._(
        data: data,
        root: root,
        firstFrameBarrier: firstFrameBarrier,
        startScreenNameProvider: startScreenNameProvider,
      );
      for (final phase in data.phases) {
        final child = root.startChild(
          phase.operation,
          description: phase.description,
          startTimestamp: phase.startTimestamp,
        )..origin = SentryTraceOrigins.autoAppStart;
        if (child is! NoOpSentrySpan) {
          provisionalChildren.add(child);
        }
        trace._finish(child, endTimestamp: phase.endTimestamp);
      }

      if (!root.tryScheduleFinalTimeout(
        createdAt.add(standaloneAppStartFinalTimeout),
      )) {
        unawaited(_flushTrace(root: root, children: provisionalChildren));
        return null;
      }
      return trace;
    } catch (error, stackTrace) {
      if (createdRoot != null) {
        unawaited(
          _flushTrace(root: createdRoot, children: provisionalChildren),
        );
      }
      internalLogger.error(
        'Failed to create static standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {
    if (_closed || _completed) return;
    _finish(_firstFrameBarrier, endTimestamp: endTimestamp.toUtc());
  }

  @override
  void finish(DateTime endTimestamp) {
    if (_closed || _completed || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
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
        _startScreenNameProvider(),
      );

      final endTimestamp = _endTimestamp;
      if (endTimestamp != null &&
          _root.status != SpanStatus.deadlineExceeded()) {
        final measurement = _data.measurementUntil(endTimestamp);
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
    }
  }

  static Future<void> _flushTrace({
    required SentryTracer root,
    Iterable<ISentrySpan> children = const [],
  }) async {
    try {
      for (final child in children) {
        if (!child.finished) {
          try {
            await child.finish();
          } catch (error, stackTrace) {
            internalLogger.error(
              'Failed to finish static app-start span',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    } finally {
      try {
        await root.finish();
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to flush static standalone app start',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _finish(ISentrySpan span, {DateTime? endTimestamp}) {
    unawaited(
      span.finish(endTimestamp: endTimestamp).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        internalLogger.error(
          'Failed to finish static app-start span',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  @override
  Future<void> close() async {
    if (_closed || _completed) return;
    _closed = true;
    await _flushTrace(root: _root, children: [_firstFrameBarrier]);
  }
}
