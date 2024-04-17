import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'local_metrics_aggregator.dart';
import 'metric.dart';

/// Class that aggregates all metrics into time buckets and sends them.
@internal
class MetricsAggregator {
  static final _defaultFlushShiftMs =
      (Random().nextDouble() * (_rollupInSeconds * 1000)).toInt();
  static const _defaultFlushInterval = Duration(seconds: 5);
  static const _defaultMaxWeight = 100000;
  static const int _rollupInSeconds = 10;

  final Duration _flushInterval;
  final int _flushShiftMs;
  final SentryOptions _options;
  final Hub _hub;
  final int _maxWeight;
  int _totalWeight = 0;
  bool _isClosed = false;
  Completer<void>? _flushCompleter;
  Timer? _flushTimer;

  /// The key for this map is the timestamp of the bucket, rounded down to the
  /// nearest RollupInSeconds. So it aggregates all the metrics over a certain
  /// time period. The Value is a map of the metrics, each of which has a key
  /// that uniquely identifies it within the time period.
  /// The [SplayTreeMap] is used so that bucket keys are ordered.
  final SplayTreeMap<int, Map<String, Metric>> _buckets = SplayTreeMap();

  MetricsAggregator({
    required SentryOptions options,
    Hub? hub,
    @visibleForTesting Duration? flushInterval,
    @visibleForTesting int? flushShiftMs,
    @visibleForTesting int? maxWeight,
  })  : _options = options,
        _hub = hub ?? HubAdapter(),
        _flushInterval = flushInterval ?? _defaultFlushInterval,
        _flushShiftMs = flushShiftMs ?? _defaultFlushShiftMs,
        _maxWeight = maxWeight ?? _defaultMaxWeight;

  /// Creates or update an existing Counter metric with [value].
  /// The metric to update is identified using [key], [unit] and [tags].
  /// The [timestamp] represents when the metric was emitted.
  void emit(
    MetricType metricType,
    String key,
    num value,
    SentryMeasurementUnit unit,
    Map<String, String> tags, {
    LocalMetricsAggregator? localMetricsAggregator,
  }) {
    if (_isClosed) {
      return;
    }

    // run before metric callback if set
    if (_options.beforeMetricCallback != null) {
      try {
        final shouldEmit = _options.beforeMetricCallback!(key, tags: tags);
        if (!shouldEmit) {
          _options.logger(
            SentryLevel.info,
            'Metric was dropped by beforeMetric',
          );
          return;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The BeforeMetric callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    final bucketKey = _getBucketKey(_options.clock());
    final bucket = _buckets.putIfAbsent(bucketKey, () => {});
    final metric = Metric.fromType(
        type: metricType, key: key, value: value, unit: unit, tags: tags);

    final oldWeight = bucket[metric.getCompositeKey()]?.getWeight() ?? 0;
    final addedWeight = metric.getWeight();
    _totalWeight += addedWeight - oldWeight;

    // Update the existing metric in the bucket.
    // If absent, add the newly created metric to the bucket.
    bucket.update(
      metric.getCompositeKey(),
      (m) => m..add(value),
      ifAbsent: () => metric,
    );

    // For sets, we only record that a value has been added to the set but not which one.
    // See develop docs: https://develop.sentry.dev/sdk/metrics/#sets
    final localAggregator =
        localMetricsAggregator ?? (_hub.getSpan()?.localMetricsAggregator);
    localAggregator?.add(
        metric, metricType == MetricType.set ? addedWeight : value);

    // Schedule the metrics flushing.
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (!_isClosed && _buckets.isNotEmpty) {
      if (_isOverWeight()) {
        _flushTimer?.cancel();
        _flush(false);
        return;
      }
      if (_flushTimer?.isActive != true) {
        _flushCompleter = Completer();
        _flushTimer = Timer(_flushInterval, () => _flush(false));
      }
    }
  }

  bool _isOverWeight() => _totalWeight >= _maxWeight;

  int getBucketWeight(final Map<String, Metric> bucket) {
    int weight = 0;
    for (final metric in bucket.values) {
      weight += metric.getWeight();
    }
    return weight;
  }

  /// Flush the metrics, then schedule next flush again.
  void _flush(bool force) async {
    if (!force && _isOverWeight()) {
      _options.logger(SentryLevel.info,
          "Metrics: total weight exceeded, flushing all buckets");
      force = true;
    }

    final flushableBucketKeys = _getFlushableBucketKeys(force);
    if (flushableBucketKeys.isEmpty) {
      _options.logger(SentryLevel.debug, 'Metrics: nothing to flush');
    } else {
      final Map<int, Iterable<Metric>> bucketsToFlush = {};

      for (final flushableBucketKey in flushableBucketKeys) {
        final bucket = _buckets.remove(flushableBucketKey);
        if (bucket != null && bucket.isNotEmpty) {
          _totalWeight -= getBucketWeight(bucket);
          bucketsToFlush[flushableBucketKey] = bucket.values;
        }
      }
      await _hub.captureMetrics(bucketsToFlush);
    }

    // Notify flush completed and reschedule flushing
    _flushTimer?.cancel();
    _flushTimer = null;
    flushCompleter?.complete(null);
    _flushCompleter = null;
    _scheduleFlush();
  }

  /// Return a list of bucket keys to flush.
  List<int> _getFlushableBucketKeys(bool force) {
    if (force) {
      return buckets.keys.toList();
    }
    // Flushable buckets are all buckets with timestamp lower than the current
    // one (so now - rollupInSeconds), minus a random duration (flushShiftMs).
    final maxTimestampToFlush = _options.clock().subtract(Duration(
          seconds: _rollupInSeconds,
          milliseconds: _flushShiftMs,
        ));
    final maxKeyToFlush = _getBucketKey(maxTimestampToFlush);

    // takeWhile works because we use a SplayTreeMap and keys are ordered.
    // toList() is needed because takeWhile is lazy and we want to remove items
    // from the buckets with these keys.
    return _buckets.keys.takeWhile((value) => value <= maxKeyToFlush).toList();
  }

  /// The timestamp of the bucket, rounded down to the nearest RollupInSeconds.
  int _getBucketKey(DateTime timestamp) {
    final seconds = timestamp.millisecondsSinceEpoch ~/ 1000;
    return (seconds ~/ _rollupInSeconds) * _rollupInSeconds;
  }

  @visibleForTesting
  SplayTreeMap<int, Map<String, Metric>> get buckets => _buckets;

  @visibleForTesting
  Completer<void>? get flushCompleter => _flushCompleter;

  void close() {
    _flush(true);
    _isClosed = true;
  }
}
