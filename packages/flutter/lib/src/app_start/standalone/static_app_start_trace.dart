// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_timing.dart';
import 'app_start_trace.dart';
import 'app_start_vitals.dart';

@internal
final class StaticAppStartTrace implements AppStartTrace {
  final AppStartTiming _timing;
  final SentryTracer _root;
  final ISentrySpan _firstFrameRenderSpan;
  final DateTime _finalDeadlineTimestamp;
  final String Function() _startScreenNameProvider;

  Timer? _finalTimeoutTimer;
  DateTime? _endTimestamp;
  AppStartTraceState _state = AppStartTraceState.open;

  StaticAppStartTrace._({
    required AppStartTiming timing,
    required SentryTracer root,
    required ISentrySpan firstFrameRenderSpan,
    required DateTime finalDeadlineTimestamp,
    required String Function() startScreenNameProvider,
  })  : _timing = timing,
        _root = root,
        _firstFrameRenderSpan = firstFrameRenderSpan,
        _finalDeadlineTimestamp = finalDeadlineTimestamp,
        _startScreenNameProvider = startScreenNameProvider;

  /// Opens the standalone root and its breakdown children.
  ///
  /// Returns `null` when the app start must not be reported: an unsampled
  /// root, an unsampled first-frame span, or a failure while building the
  /// children. Anything already created is flushed, so no span outlives a
  /// failed creation.
  static StaticAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartTiming timing,
    required String Function() startScreenNameProvider,
  }) {
    // onFinish captures `trace` below before it is assigned. The tracer cannot
    // finish before it has a child, and the first child is created after the
    // assignment, so the null-aware call never drops an enrichment.
    StaticAppStartTrace? trace;
    // Held outside the try so a partially built trace can still be flushed.
    SentryTracer? root;
    try {
      final createdAt = hub.options.clock();
      final createdRoot = hub.startTransactionWithContext(
        SentryTransactionContext(
          standaloneAppStartRootName,
          SentrySpanOperations.appStart,
          origin: SentryTraceOrigins.autoAppStart,
        ),
        startTimestamp: timing.processStartTimestamp,
        waitForChildren: true,
        autoFinishAfter: standaloneAppStartIdleTimeout,
        bindToScope: false,
        trimEnd: true,
        onFinish: (_) => trace?._enrichAndComplete(),
      );
      if (createdRoot is! SentryTracer) return null;
      root = createdRoot;

      if (root.samplingDecision?.sampled != true) {
        return _abort(root, 'root span is not sampled');
      }

      final firstFrameRenderSpan = root.startChild(
        SentrySpanOperations.appStartFirstFrameRender,
        description: appStartFirstFrameRenderDescription,
        startTimestamp: timing.sentrySetupTimestamp,
      )..origin = SentryTraceOrigins.autoAppStart;
      if (firstFrameRenderSpan.samplingDecision?.sampled != true) {
        return _abort(root, 'first-frame span is not sampled');
      }

      trace = StaticAppStartTrace._(
        timing: timing,
        root: root,
        firstFrameRenderSpan: firstFrameRenderSpan,
        finalDeadlineTimestamp:
            createdAt.add(standaloneAppStartFinalTimeout).toUtc(),
        startScreenNameProvider: startScreenNameProvider,
      );

      for (final phase in timing.phases) {
        final child = root.startChild(
          phase.kind.operation,
          description: phase.description,
          startTimestamp: phase.startTimestamp,
        )..origin = SentryTraceOrigins.autoAppStart;
        unawaited(_finishSpan(child, endTimestamp: phase.endTimestamp));
      }

      trace._scheduleFinalTimeout();
      return trace;
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to create static standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return root == null ? null : _abort(root);
    }
  }

  /// Flushes everything created so far and reports no trace.
  static StaticAppStartTrace? _abort(SentryTracer root, [String? reason]) {
    if (reason != null) {
      internalLogger.info('Skipping static standalone app start: $reason');
    }
    unawaited(_flushTrace(root));
    return null;
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {
    if (_state.isTerminal || _endTimestamp != null) return;
    // Set before finishing the child: finishing the last outstanding child can
    // complete the tracer, which enriches from _endTimestamp.
    _endTimestamp = endTimestamp.toUtc();
    _root.scheduleFinish();
    unawaited(
      _finishSpan(_firstFrameRenderSpan, endTimestamp: _endTimestamp),
    );
  }

  @override
  Future<void> close() async {
    if (_state.isTerminal) return;
    _state = AppStartTraceState.closed;
    _clearFinalTimeout();
    await _flushTrace(_root);
  }

  void _enrichAndComplete() {
    if (_state == AppStartTraceState.completed) return;
    _clearFinalTimeout();
    try {
      final vitals = AppStartVitals.resolve(
        timing: _timing,
        screen: _startScreenNameProvider(),
        endTimestamp: _endTimestamp,
        deadlineExceeded: _root.status == SpanStatus.deadlineExceeded(),
      );

      final type = vitals.type.name;
      _root.setData(SentrySpanData.appStartTypeKey, type);
      _root.setData(SemanticAttributesConstants.appVitalsStartType, type);
      _root.setData(
        SemanticAttributesConstants.appVitalsStartScreen,
        vitals.screen,
      );

      final measurement = vitals.measurement;
      if (measurement != null) {
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
      _state = AppStartTraceState.completed;
    }
  }

  void _scheduleFinalTimeout() {
    _finalTimeoutTimer = Timer(standaloneAppStartFinalTimeout, () {
      unawaited(
        _finishAtDeadline().catchError((Object error, StackTrace stackTrace) {
          internalLogger.error(
            'Failed to finish static app start at final deadline',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    });
  }

  /// Force-ends the trace once the hard deadline passes.
  ///
  /// Runs at most once — the final-timeout [Timer] is one-shot — so no
  /// re-entry guard is needed beyond the terminal check. The state stays
  /// [AppStartTraceState.open] throughout, which lets a first frame arriving
  /// between the awaits below still run [recordFirstFrame]. That is harmless:
  /// the root is already `deadlineExceeded`, so the vitals omit the duration
  /// either way.
  Future<void> _finishAtDeadline() async {
    if (_state.isTerminal) return;
    _clearFinalTimeout();

    final status = SpanStatus.deadlineExceeded();
    _root.status = status;

    // The tracer stores parents before descendants. Reverse the list so finish
    // callbacks observe a drained subtree before its parent ends.
    for (final child in _root.children.reversed.toList()) {
      if (!child.finished) {
        await _finishSpan(
          child,
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

  /// Finishes every open child and then the root.
  ///
  /// Reads the children off the tracer, which owns them — no-op spans are
  /// never added to it, so there is nothing to filter out here.
  static Future<void> _flushTrace(SentryTracer root) async {
    for (final child in root.children.toList()) {
      if (!child.finished) {
        await _finishSpan(child);
      }
    }
    await _finishSpan(root);
  }

  static Future<void> _finishSpan(
    ISentrySpan span, {
    SpanStatus? status,
    DateTime? endTimestamp,
  }) async {
    try {
      await span.finish(status: status, endTimestamp: endTimestamp);
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to finish static standalone app-start span',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
