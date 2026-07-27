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

  final _StaticAppStartExtensionLifecycle _extensionLifecycle;
  Timer? _finalTimeoutTimer;
  DateTime? _endTimestamp;
  AppStartTraceState _state = AppStartTraceState.open;

  // The final deadline drains descendants asynchronously. Block extension
  // mutations while that sweep is in progress.
  bool _finalizing = false;

  bool get _isFinalizingOrTerminal => _finalizing || _state.isTerminal;

  StaticAppStartTrace._({
    required Hub hub,
    required AppStartTiming timing,
    required SentryTracer root,
    required ISentrySpan firstFrameRenderSpan,
    required DateTime finalDeadlineTimestamp,
    required String Function() startScreenNameProvider,
  })  : _timing = timing,
        _root = root,
        _firstFrameRenderSpan = firstFrameRenderSpan,
        _finalDeadlineTimestamp = finalDeadlineTimestamp,
        _startScreenNameProvider = startScreenNameProvider,
        _extensionLifecycle = _StaticAppStartExtensionLifecycle(
          hub: hub,
          root: root,
        );

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
        hub: hub,
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
  bool tryExtend(DateTime startTimestamp) {
    if (_isFinalizingOrTerminal || _firstFrameRenderSpan.endTimestamp != null) {
      return false;
    }

    return _extensionLifecycle.tryStart(startTimestamp);
  }

  @override
  ISentrySpan? get extendedSpan => _extensionLifecycle.activeSpan;

  @override
  SentrySpanV2? get extendedSpanV2 => null;

  @override
  Future<void> finishExtended(DateTime endTimestamp) {
    if (_isFinalizingOrTerminal) {
      return Future<void>.value();
    }

    return _extensionLifecycle.finish(endTimestamp);
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
    await _extensionLifecycle.close();
    await _flushTrace(_root);
  }

  void _enrichAndComplete() {
    if (_state == AppStartTraceState.completed) return;
    _clearFinalTimeout();
    try {
      final vitals = AppStartVitals.resolve(
        timing: _timing,
        screen: _startScreenNameProvider(),
        endTimestamp: resolveAppStartMeasurementEnd(
          _endTimestamp,
          _extensionLifecycle.completionSnapshot,
        ),
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
  /// Runs at most once — the final-timeout [Timer] is one-shot — so the
  /// terminal check is enough to keep it out; [_finalizing] is what keeps
  /// extensions out while the drain below awaits. The state stays
  /// [AppStartTraceState.open] throughout, which lets a first frame arriving
  /// between the awaits below still run [recordFirstFrame]. That is harmless:
  /// the root is already `deadlineExceeded`, so the vitals omit the duration
  /// either way.
  Future<void> _finishAtDeadline() async {
    if (_isFinalizingOrTerminal) return;
    _finalizing = true;
    _clearFinalTimeout();

    final status = SpanStatus.deadlineExceeded();
    _root.status = status;

    await _extensionLifecycle.waitForPendingFinish();
    if (_state.isTerminal) return;

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

final class _StaticAppStartExtensionLifecycle {
  final Hub _hub;
  final SentryTracer _root;

  late final SdkLifecycleCallback<OnSpanFinish> _spanFinishCallback;
  SentrySpan? _span;
  Future<void>? _finishFuture;
  DateTime? _endTimestamp;
  bool _closed = false;

  _StaticAppStartExtensionLifecycle({
    required Hub hub,
    required SentryTracer root,
  })  : _hub = hub,
        _root = root {
    _spanFinishCallback = _handleSpanFinish;
  }

  bool tryStart(DateTime startTimestamp) {
    if (_closed || _span != null) return false;

    final span = _root.startChild(
      SentrySpanOperations.appStartExtended,
      description: standaloneExtendedAppStartName,
      startTimestamp: startTimestamp.toUtc(),
    );
    if (span is! SentrySpan) return false;

    span.origin = SentryTraceOrigins.autoAppStart;
    _span = span;
    _hub.options.lifecycleRegistry.registerCallback<OnSpanFinish>(
      _spanFinishCallback,
    );
    return true;
  }

  ISentrySpan? get activeSpan {
    final span = _span;
    return span == null || span.finished ? null : span;
  }

  AppStartExtensionOutcome get completionSnapshot {
    final span = _span;
    return (
      completed: span == null || (span.finished && _endTimestamp != null),
      endTimestamp: _endTimestamp,
    );
  }

  Future<void> finish(DateTime endTimestamp) {
    if (_closed || _span == null) return Future<void>.value();
    return _finishFuture ??= _finishSpan(endTimestamp.toUtc());
  }

  Future<void> waitForPendingFinish() async {
    final finishFuture = _finishFuture;
    if (finishFuture != null) await finishFuture;
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

  // Handle callers finishing the span directly instead of using
  // finishExtendedAppStart().
  void _handleSpanFinish(OnSpanFinish event) {
    final span = _span;
    if (span == null || !identical(event.span, span) || _endTimestamp != null) {
      return;
    }

    final endTimestamp = span.endTimestamp;
    if (endTimestamp == null) return;

    _endTimestamp = endTimestamp;
    if (_root.status != SpanStatus.deadlineExceeded()) {
      span.status = SpanStatus.ok();
    }
    _removeSpanFinishCallback();
  }

  Future<void> _finishSpan(DateTime? endTimestamp) async {
    if (_endTimestamp != null) return;
    final span = _span;
    try {
      final timestamp =
          (span?.endTimestamp ?? endTimestamp ?? _hub.options.clock()).toUtc();
      _endTimestamp = timestamp;
      if (span == null) return;

      span.status = SpanStatus.ok();
      if (!span.finished) {
        await span.finish(endTimestamp: timestamp);
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to finish static extended app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _removeSpanFinishCallback();
    }
  }

  void _removeSpanFinishCallback() {
    _hub.options.lifecycleRegistry.removeCallback<OnSpanFinish>(
      _spanFinishCallback,
    );
  }
}
