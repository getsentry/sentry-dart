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
  final ISentrySpan _firstFrameRenderSpan;
  final DateTime _finalDeadlineTimestamp;
  final String Function() _startScreenNameProvider;

  Timer? _finalTimeoutTimer;
  DateTime? _endTimestamp;
  bool _finalizing = false;
  bool _completed = false;
  bool _closed = false;

  StaticAppStartTrace._({
    required AppStartData data,
    required SentryTracer root,
    required ISentrySpan firstFrameRenderSpan,
    required DateTime finalDeadlineTimestamp,
    required String Function() startScreenNameProvider,
  })  : _data = data,
        _root = root,
        _firstFrameRenderSpan = firstFrameRenderSpan,
        _finalDeadlineTimestamp = finalDeadlineTimestamp,
        _startScreenNameProvider = startScreenNameProvider;

  static StaticAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required String Function() startScreenNameProvider,
  }) {
    StaticAppStartTrace? trace;
    SentryTracer? createdRoot;
    final children = <ISentrySpan>[];
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

      final firstFrameRenderSpan = root.startChild(
        SentrySpanOperations.appStartFirstFrameRender,
        description: appStartFirstFrameRenderDescription,
        startTimestamp: data.sentrySetupTimestamp,
      )..origin = SentryTraceOrigins.autoAppStart;
      if (firstFrameRenderSpan is! NoOpSentrySpan) {
        children.add(firstFrameRenderSpan);
      }
      if (firstFrameRenderSpan.samplingDecision?.sampled != true) {
        unawaited(_flushTrace(root: root, children: children));
        return null;
      }

      trace = StaticAppStartTrace._(
        data: data,
        root: root,
        firstFrameRenderSpan: firstFrameRenderSpan,
        finalDeadlineTimestamp:
            createdAt.add(standaloneAppStartFinalTimeout).toUtc(),
        startScreenNameProvider: startScreenNameProvider,
      );
      for (final phase in data.phases) {
        final child = root.startChild(
          phase.operation,
          description: phase.description,
          startTimestamp: phase.startTimestamp,
        )..origin = SentryTraceOrigins.autoAppStart;
        if (child is! NoOpSentrySpan) {
          children.add(child);
        }
        unawaited(
          _finishSpanSafely(
            child,
            endTimestamp: phase.endTimestamp,
            failureMessage: 'Failed to finish static app-start span',
          ),
        );
      }

      trace._scheduleFinalTimeout(hub.options.clock());
      return trace;
    } catch (error, stackTrace) {
      if (createdRoot != null) {
        unawaited(_flushTrace(root: createdRoot, children: children));
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
    _root.scheduleFinish();
    unawaited(
      _finishSpanSafely(
        _firstFrameRenderSpan,
        endTimestamp: endTimestamp.toUtc(),
        failureMessage: 'Failed to finish static app-start span',
      ),
    );
  }

  @override
  void finish(DateTime endTimestamp) {
    if (_closed || _completed || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
    _root.scheduleFinish();
  }

  void _enrichAndComplete() {
    if (_completed) return;
    _clearFinalTimeout();
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

  void _scheduleFinalTimeout(DateTime now) {
    void finishAtDeadline() {
      unawaited(
        _finishAtDeadline().catchError((Object error, StackTrace stackTrace) {
          internalLogger.error(
            'Failed to finish static app start at final deadline',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }

    final remaining = _finalDeadlineTimestamp.difference(now.toUtc());
    if (remaining <= Duration.zero) {
      finishAtDeadline();
    } else {
      _finalTimeoutTimer = Timer(remaining, finishAtDeadline);
    }
  }

  Future<void> _finishAtDeadline() async {
    if (_closed || _completed || _finalizing) return;
    _finalizing = true;
    _clearFinalTimeout();

    final status = SpanStatus.deadlineExceeded();
    _root.status = status;

    // The tracer stores parents before descendants. Reverse the list so finish
    // callbacks observe a drained subtree before its parent ends.
    for (final child in _root.children.reversed.toList()) {
      if (!child.finished) {
        await child.finish(
          status: status,
          endTimestamp: _finalDeadlineTimestamp,
        );
      }
    }

    await _root.finish(status: status, endTimestamp: _finalDeadlineTimestamp);
  }

  void _clearFinalTimeout() {
    _finalTimeoutTimer?.cancel();
    _finalTimeoutTimer = null;
  }

  static Future<void> _flushTrace({
    required SentryTracer root,
    Iterable<ISentrySpan> children = const [],
  }) async {
    for (final child in children) {
      if (!child.finished) {
        await _finishSpanSafely(
          child,
          failureMessage: 'Failed to finish static app-start span',
        );
      }
    }
    await _finishSpanSafely(
      root,
      failureMessage: 'Failed to flush static standalone app start',
    );
  }

  static Future<void> _finishSpanSafely(
    ISentrySpan span, {
    DateTime? endTimestamp,
    required String failureMessage,
  }) async {
    try {
      await span.finish(endTimestamp: endTimestamp);
    } catch (error, stackTrace) {
      internalLogger.error(
        failureMessage,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed || _completed) return;
    _closed = true;
    _clearFinalTimeout();
    await _flushTrace(root: _root, children: _root.children.toList());
  }
}
