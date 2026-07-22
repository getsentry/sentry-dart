// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'profiling.dart';
import 'utils/internal_logger.dart';
import 'utils/sample_rate_format.dart';

@internal
class SentryTracer extends ISentrySpan {
  final Hub _hub;
  late bool _waitForChildren;
  late String name;

  late final SentrySpan _rootSpan;
  final List<SentrySpan> _children = [];
  final Map<String, dynamic> _extra = {};

  final Map<String, SentryMeasurement> _measurements = {};
  Map<String, SentryMeasurement> get measurements => _measurements;

  Timer? _autoFinishAfterTimer;
  Timer? _finalTimeoutTimer;
  DateTime? _finalDeadlineTimestamp;
  Duration? _autoFinishAfter;

  @visibleForTesting
  Timer? get autoFinishAfterTimer => _autoFinishAfterTimer;

  @visibleForTesting
  Timer? get finalTimeoutTimer => _finalTimeoutTimer;

  OnTransactionFinish? _onFinish;

  /// [finish] was called but [waitForChildren] is still blocking capture.
  bool _finishRequested = false;

  /// In-flight capture path; concurrent callers join this future.
  Future<void>? _finalizeFuture;

  /// Successfully captured (or root already finished before finalize).
  bool _captured = false;

  SpanStatus? _requestedStatus;
  bool _deadlineFinalization = false;
  bool _profilerDisposed = false;
  late final bool _trimEnd;

  late SentryTransactionNameSource transactionNameSource;

  SentryTraceContextHeader? _sentryTraceContextHeader;

  // Profiler attached to this tracer.
  late final SentryProfiler? profiler;

  // Resulting profile, after it has been collected.  This is later used by
  // SentryClient to attach as an envelope item when sending the transaction.
  SentryProfileInfo? profileInfo;

  /// If [waitForChildren] is true, this transaction will not finish until all
  /// its children are finished.
  ///
  /// When [autoFinishAfter] is provided, started transactions will
  /// automatically be finished after this duration.
  ///
  /// If [trimEnd] is true, sets the end timestamp of the transaction to the
  /// highest timestamp of child spans, trimming the duration of the
  /// transaction. This is useful to discard extra time in the transaction that
  /// is not accounted for in child spans, like what happens in the
  /// [SentryNavigatorObserver](https://pub.dev/documentation/sentry_flutter/latest/sentry_flutter/SentryNavigatorObserver-class.html)
  /// idle transactions, where we finish the transaction after a given
  /// "idle time" and we don't want this "idle time" to be part of the transaction.
  SentryTracer(
    SentryTransactionContext transactionContext,
    this._hub, {
    DateTime? startTimestamp,
    bool waitForChildren = false,
    Duration? autoFinishAfter,
    bool trimEnd = false,
    OnTransactionFinish? onFinish,
    this.profiler,
  }) {
    _rootSpan = SentrySpan(
      this,
      transactionContext,
      _hub,
      samplingDecision: transactionContext.samplingDecision,
      startTimestamp: startTimestamp,
      isRootSpan: true,
    );
    _waitForChildren = waitForChildren;
    _autoFinishAfter = autoFinishAfter;

    _scheduleTimer();
    name = transactionContext.name;
    // always default to custom if not provided
    transactionNameSource = transactionContext.transactionNameSource ??
        SentryTransactionNameSource.custom;
    _trimEnd = trimEnd;
    _onFinish = onFinish;

    for (final collector in _hub.options.performanceCollectors) {
      if (collector is PerformanceContinuousCollector) {
        collector.onSpanStarted(_rootSpan);
      }
    }
    _dispatchOnSpanStart(_rootSpan);
  }

  @override
  Future<void> finish({
    SpanStatus? status,
    DateTime? endTimestamp,
    Hint? hint,
  }) {
    if (_captured) return Future.value();
    final inFlight = _finalizeFuture;
    if (inFlight != null) return inFlight;

    _autoFinishAfterTimer?.cancel();
    _requestedStatus = status;
    if (_rootSpan.finished) {
      _captured = true;
      return Future.value();
    }
    if (_waitForChildren && !_haveAllChildrenFinished()) {
      _finishRequested = true;
      return Future.value();
    }

    return _beginFinalization(
      endTimestamp: endTimestamp ?? _hub.options.clock(),
      hint: hint,
    );
  }

  Future<void> _beginFinalization({
    required DateTime endTimestamp,
    Hint? hint,
  }) {
    if (_captured) return Future.value();
    final inFlight = _finalizeFuture;
    if (inFlight != null) return inFlight;

    _finishRequested = false;
    final future = _finalize(endTimestamp: endTimestamp, hint: hint);
    _finalizeFuture = future;
    return future;
  }

  Future<void> _finalize({
    required DateTime endTimestamp,
    Hint? hint,
  }) async {
    try {
      if (_deadlineFinalization) {
        await _applyDeadlineState();
      } else {
        _rootSpan.status ??= _requestedStatus;
      }

      // remove span where its endTimestamp is before startTimestamp
      _children.removeWhere(
          (span) => !_hasSpanSuitableTimestamps(span, endTimestamp));

      var rootEndTimestamp = _deadlineFinalization
          ? _finalDeadlineTimestamp ?? endTimestamp
          : endTimestamp;

      // Trim the end timestamp of the transaction to the very last timestamp of child spans
      if (_trimEnd && children.isNotEmpty) {
        DateTime? latestEndTime;

        for (final child in children) {
          final childEndTimestamp = child.endTimestamp;
          if (childEndTimestamp != null) {
            if (latestEndTime == null ||
                childEndTimestamp.isAfter(latestEndTime)) {
              latestEndTime = child.endTimestamp;
            }
          }
        }

        if (latestEndTime != null) {
          rootEndTimestamp = latestEndTime;
        }
      }

      // the callback should run before because if the span is finished,
      // we cannot attach data, its immutable after being finished.
      final finish = _onFinish?.call(this);
      if (finish is Future) {
        await finish;
      }

      // Deadline may have been requested while onFinish was awaiting; re-apply
      // and pin the root end to the deadline (overrides trimEnd).
      if (_deadlineFinalization) {
        await _applyDeadlineState();
        rootEndTimestamp = _finalDeadlineTimestamp ?? rootEndTimestamp;
      }
      await _rootSpan.finish(endTimestamp: rootEndTimestamp, hint: hint);

      // remove from scope
      await _hub.configureScope((scope) {
        if (scope.span == this) {
          scope.span = null;
        }
      });

      // if it's an idle transaction which has no children, we drop it to save user's quota
      if (children.isEmpty && _autoFinishAfter != null) {
        _clearFinalTimeoutTimer();
        return;
      }

      final transaction = SentryTransaction(this);
      transaction.measurements.addAll(_measurements);

      profileInfo =
          (_rootSpan.status == null || _rootSpan.status == SpanStatus.ok())
              ? await profiler?.finishFor(transaction)
              : null;

      await _hub.captureTransaction(
        transaction,
        traceContext: traceContext(),
        hint: hint,
      );
      _captured = true;
      _clearFinalTimeoutTimer();
    } finally {
      _disposeProfiler();
    }
  }

  Future<void> _applyDeadlineState() async {
    final deadline = _finalDeadlineTimestamp;
    if (deadline == null) return;

    final deadlineStatus = SpanStatus.deadlineExceeded();
    _rootSpan.status = deadlineStatus;
    final children = List<SentrySpan>.of(_children);
    for (final child in children) {
      if (child.finished) continue;
      child.status = deadlineStatus;
      if (child.startTimestamp.isAfter(deadline)) {
        _children.remove(child);
        await child.finish(status: deadlineStatus);
      } else {
        await child.finish(
          status: deadlineStatus,
          endTimestamp: deadline,
        );
      }
    }
  }

  @internal
  bool tryScheduleFinalTimeout(DateTime deadlineTimestamp) {
    if (_finalDeadlineTimestamp != null ||
        _finalizeFuture != null ||
        finished) {
      return false;
    }

    _finalDeadlineTimestamp = deadlineTimestamp.toUtc();
    final remaining = _finalDeadlineTimestamp!.difference(_hub.options.clock());
    if (remaining <= Duration.zero) {
      _finishAtDeadlineSafely();
    } else {
      _finalTimeoutTimer = Timer(remaining, () {
        _finishAtDeadlineSafely();
      });
    }
    return true;
  }

  void _finishAtDeadlineSafely() {
    unawaited(
        _finishAtDeadline().catchError((Object error, StackTrace stackTrace) {
      internalLogger.error(
        'Failed to finish tracer at final deadline.',
        error: error,
        stackTrace: stackTrace,
      );
    }));
  }

  void _clearFinalTimeoutTimer() {
    _finalTimeoutTimer?.cancel();
    _finalTimeoutTimer = null;
  }

  Future<void> _finishAtDeadline() {
    if (_captured) return Future.value();

    _deadlineFinalization = true;
    _requestedStatus = SpanStatus.deadlineExceeded();
    final inFlight = _finalizeFuture;
    if (inFlight != null) return inFlight;

    return _beginFinalization(
      endTimestamp: _finalDeadlineTimestamp ?? _hub.options.clock(),
    );
  }

  void _disposeProfiler() {
    if (_profilerDisposed) return;
    _profilerDisposed = true;
    profiler?.dispose();
  }

  @override
  void removeData(String key) {
    if (finished) {
      return;
    }

    _extra.remove(key);
  }

  @override
  void removeTag(String key) {
    if (finished) {
      return;
    }

    _rootSpan.removeTag(key);
  }

  @override
  void setData(String key, dynamic value) {
    if (finished) {
      return;
    }

    _extra[key] = value;
  }

  @override
  void setTag(String key, String value) {
    if (finished) {
      return;
    }

    _rootSpan.setTag(key, value);
  }

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    if (!_acceptsChildren) {
      return NoOpSentrySpan();
    }

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.log(
        SentryLevel.warning,
        'Span operation: $operation, description: $description dropped due to limit reached. Returning NoOpSpan.',
      );
      return NoOpSentrySpan();
    }

    return _rootSpan.startChild(
      operation,
      description: description,
      startTimestamp: startTimestamp,
    );
  }

  ISentrySpan startChildWithParentSpanId(
    SpanId parentSpanId,
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    if (!_acceptsChildren) {
      return NoOpSentrySpan();
    }

    // reset the timer if a new child is added
    _scheduleTimer();

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.log(
        SentryLevel.warning,
        'Span operation: $operation, description: $description dropped due to limit reached. Returning NoOpSpan.',
      );
      return NoOpSentrySpan();
    }

    final context = SentrySpanContext(
        traceId: _rootSpan.context.traceId,
        parentSpanId: parentSpanId,
        operation: operation,
        description: description);

    final child = SentrySpan(
      this,
      context,
      _hub,
      samplingDecision: _rootSpan.samplingDecision,
      startTimestamp: startTimestamp,
      finishedCallback: _finishedCallback,
    );

    _children.add(child);

    for (final collector in _hub.options.performanceCollectors) {
      if (collector is PerformanceContinuousCollector) {
        collector.onSpanStarted(child);
      }
    }
    _dispatchOnSpanStart(child);

    return child;
  }

  Future<void> _finishedCallback({
    DateTime? endTimestamp,
    Hint? hint,
  }) async {
    if (_finishRequested) {
      await finish(
        status: _requestedStatus,
        endTimestamp: endTimestamp,
        hint: hint,
      );
    }
  }

  @override
  SpanStatus? get status => _rootSpan.status;

  @override
  SentrySpanContext get context => _rootSpan.context;

  @override
  String? get origin => _rootSpan.origin;

  @override
  set origin(String? origin) => _rootSpan.origin = origin;

  @override
  DateTime get startTimestamp => _rootSpan.startTimestamp;

  @override
  DateTime? get endTimestamp => _rootSpan.endTimestamp;

  Map<String, dynamic> get data => Map.unmodifiable(_extra);

  @override
  bool get finished => _rootSpan.finished || _captured;

  bool get _acceptsChildren => !_captured && _finalizeFuture == null;

  List<SentrySpan> get children => _children;

  @override
  dynamic get throwable => _rootSpan.throwable;

  @override
  set throwable(throwable) => _rootSpan.throwable = throwable;

  @override
  set status(SpanStatus? status) => _rootSpan.status = status;

  Map<String, String> get tags => _rootSpan.tags;

  @override
  SentryTraceHeader toSentryTrace() => _rootSpan.toSentryTrace();

  bool _haveAllChildrenFinished() {
    for (final child in children) {
      if (!child.finished) {
        return false;
      }
    }
    return true;
  }

  bool _hasSpanSuitableTimestamps(
          SentrySpan span, DateTime endTimestampCandidate) =>
      !span.startTimestamp
          .isAfter((span.endTimestamp ?? endTimestampCandidate));

  @override
  void setMeasurement(String name, num value, {SentryMeasurementUnit? unit}) {
    if (finished) {
      _hub.options.log(SentryLevel.debug,
          "The tracer is already finished. Measurement $name cannot be set");
      return;
    }
    _measurements[name] = SentryMeasurement(name, value, unit: unit);
  }

  void setMeasurementFromChild(String name, num value,
      {SentryMeasurementUnit? unit}) {
    // We don't want to overwrite span measurement, if it comes from a child.
    if (!_measurements.containsKey(name)) {
      setMeasurement(name, value, unit: unit);
    }
  }

  @override
  SentryBaggageHeader? toBaggageHeader() {
    final context = traceContext();

    if (context != null) {
      final baggage = context.toBaggage();
      return SentryBaggageHeader.fromBaggage(baggage);
    }
    return null;
  }

  @override
  SentryTraceContextHeader? traceContext() {
    // TODO: freeze context after 1st envelope or outgoing HTTP request
    if (_sentryTraceContextHeader != null) {
      return _sentryTraceContextHeader;
    }

    _sentryTraceContextHeader = SentryTraceContextHeader(
      _rootSpan.context.traceId,
      _hub.options.parsedDsn.publicKey,
      release: _hub.options.release,
      environment: _hub.options.environment,
      userId: null, // because of PII not sending it for now
      transaction:
          _isHighQualityTransactionName(transactionNameSource) ? name : null,
      sampleRate: _sampleRateToString(_rootSpan.samplingDecision?.sampleRate),
      sampleRand: _sampleRandToString(_rootSpan.samplingDecision?.sampleRand),
      sampled: _rootSpan.samplingDecision?.sampled.toString(),
      orgId: _hub.options.effectiveOrgId,
    );

    return _sentryTraceContextHeader;
  }

  String? _sampleRateToString(double? sampleRate) {
    if (!isValidSampleRate(sampleRate)) {
      return null;
    }
    return sampleRate != null ? SampleRateFormat().format(sampleRate) : null;
  }

  String? _sampleRandToString(double? sampleRand) {
    if (!isValidSampleRand(sampleRand)) {
      return null;
    }
    return sampleRand != null ? SampleRateFormat().format(sampleRand) : null;
  }

  bool _isHighQualityTransactionName(SentryTransactionNameSource source) {
    return source != SentryTransactionNameSource.url;
  }

  @override
  SentryTracesSamplingDecision? get samplingDecision =>
      _rootSpan.samplingDecision;

  @override
  void scheduleFinish() {
    if (finished) {
      return;
    }
    if (_autoFinishAfterTimer != null) {
      _finishRequested = false;
      _scheduleTimer();
    }
  }

  void _scheduleTimer() {
    final autoFinishAfter = _autoFinishAfter;
    if (autoFinishAfter != null) {
      _autoFinishAfterTimer?.cancel();
      _autoFinishAfterTimer = Timer(autoFinishAfter, () async {
        await finish(status: status ?? SpanStatus.ok());
      });
    }
  }

  void _dispatchOnSpanStart(ISentrySpan span) {
    _hub.options.lifecycleRegistry.dispatchCallback(OnSpanStart(span));
  }
}
