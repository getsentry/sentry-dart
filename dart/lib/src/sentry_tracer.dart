import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'metrics/local_metrics_aggregator.dart';
import 'profiling.dart';
import 'sentry_tracer_finish_status.dart';
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

  Timer? _autoFinishAfterTimer;
  Duration? _autoFinishAfter;

  @visibleForTesting
  Timer? get autoFinishAfterTimer => _autoFinishAfterTimer;

  OnTransactionFinish? _onFinish;
  var _finishStatus = SentryTracerFinishStatus.notFinishing();
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
  }

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {
    final commonEndTimestamp = endTimestamp ?? _hub.options.clock();
    _autoFinishAfterTimer?.cancel();
    _finishStatus = SentryTracerFinishStatus.finishing(status);
    if (_rootSpan.finished) {
      return;
    }
    if (_waitForChildren && !_haveAllChildrenFinished()) {
      return;
    }
    try {
      _rootSpan.status ??= status;

      // remove span where its endTimestamp is before startTimestamp
      _children.removeWhere(
          (span) => !_hasSpanSuitableTimestamps(span, commonEndTimestamp));

      var _rootEndTimestamp = commonEndTimestamp;

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
          _rootEndTimestamp = latestEndTime;
        }
      }

      // the callback should run before because if the span is finished,
      // we cannot attach data, its immutable after being finished.
      final finish = _onFinish?.call(this);
      if (finish is Future) {
        await finish;
      }
      await _rootSpan.finish(endTimestamp: _rootEndTimestamp);

      // remove from scope
      await _hub.configureScope((scope) {
        if (scope.span == this) {
          scope.span = null;
        }
      });

      // if it's an idle transaction which has no children, we drop it to save user's quota
      if (children.isEmpty && _autoFinishAfter != null) {
        return;
      }

      final transaction = SentryTransaction(this);
      transaction.measurements.addAll(_measurements);

      profileInfo = (status == null || status == SpanStatus.ok())
          ? await profiler?.finishFor(transaction)
          : null;

      await _hub.captureTransaction(
        transaction,
        traceContext: traceContext(),
      );
    } finally {
      profiler?.dispose();
    }
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
    if (finished) {
      return NoOpSentrySpan();
    }

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.logger(
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
    if (finished) {
      return NoOpSentrySpan();
    }

    // reset the timer if a new child is added
    _scheduleTimer();

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.logger(
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

    return child;
  }

  Future<void> _finishedCallback({
    DateTime? endTimestamp,
  }) async {
    final finishStatus = _finishStatus;
    if (finishStatus.finishing) {
      await finish(status: finishStatus.status, endTimestamp: endTimestamp);
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
  bool get finished => _rootSpan.finished;

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

  @visibleForTesting
  Map<String, SentryMeasurement> get measurements =>
      Map.unmodifiable(_measurements);

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
      return;
    }
    final measurement = SentryMeasurement(name, value, unit: unit);
    _measurements[name] = measurement;
  }

  @override
  SentryBaggageHeader? toBaggageHeader() {
    final context = traceContext();

    if (context != null) {
      final baggage = context.toBaggage(logger: _hub.options.logger);
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

    SentryUser? user;
    _hub.configureScope((scope) => user = scope.user);

    _sentryTraceContextHeader = SentryTraceContextHeader(
      _rootSpan.context.traceId,
      Dsn.parse(_hub.options.dsn!).publicKey,
      release: _hub.options.release,
      environment: _hub.options.environment,
      userId: null, // because of PII not sending it for now
      userSegment: user?.segment,
      transaction:
          _isHighQualityTransactionName(transactionNameSource) ? name : null,
      sampleRate: _sampleRateToString(_rootSpan.samplingDecision?.sampleRate),
      sampled: _rootSpan.samplingDecision?.sampled.toString(),
    );

    return _sentryTraceContextHeader;
  }

  String? _sampleRateToString(double? sampleRate) {
    if (!isValidSampleRate(sampleRate)) {
      return null;
    }
    return sampleRate != null ? SampleRateFormat().format(sampleRate) : null;
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

  @override
  LocalMetricsAggregator? get localMetricsAggregator =>
      _rootSpan.localMetricsAggregator;
}
