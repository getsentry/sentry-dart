import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'metric.dart';

/// Class that aggregates all metrics into time buckets and sends them.
@internal
class MetricsAggregator {
  static const Duration _flushInterval = Duration(seconds: 5);

  static const int _rollupInSeconds = 10;

  final int _flushShiftMs =
      (Random().nextDouble() * (_rollupInSeconds * 1000)).toInt();

  final SentryOptions _options;
  bool _isClosed = false;
  Completer<void>? _flushCompleter;

  /// The key for this map is the timestamp of the bucket, rounded down to the
  /// nearest RollupInSeconds. So it aggregates all the metrics over a certain
  /// time period. The Value is a map of the metrics, each of which has a key
  /// that uniquely identifies it within the time period.
  /// The [SplayTreeMap] is used so that bucket keys are ordered.
  final SplayTreeMap<int, Map<String, Metric>> buckets = SplayTreeMap();

  MetricsAggregator({required SentryOptions options}) : _options = options;

  /// Creates or update an existing Counter metric with [value].
  /// The metric to update is identified using [key], [unit] and [tags].
  /// The [timestamp] represents when the metric was emitted.
  void increment(
    String key,
    double value,
    SentryMeasurementUnit unit,
    Map<String, String> tags,
    DateTime timestamp,
  ) {
    if (_isClosed) {
      return;
    }

    final int bucketKey = _getBucketKey(timestamp);
    final Map<String, Metric> bucket = buckets.putIfAbsent(bucketKey, () => {});
    final Metric metric = CounterMetric(
        value: value, key: key, timestamp: timestamp, unit: unit, tags: tags);

    // Update the existing metric in the bucket.
    // If absent, add the newly created metric to the bucket.
    bucket.update(
      metric.getCompositeKey(),
      (m) => m..add(value),
      ifAbsent: () => metric,
    );

    // Schedule the metrics flushing.
    _scheduleFlush();
  }

  Future<void> _scheduleFlush() async {
    if (!_isClosed &&
        buckets.isNotEmpty &&
        _flushCompleter?.isCompleted != false) {
      _flushCompleter = Completer();

      await _flushCompleter?.future
          .timeout(_flushInterval, onTimeout: _flushMetrics);
    }
  }

  /// Flush the metrics, then schedule next flush again.
  void _flushMetrics() async {
    await _flush();

    _flushCompleter?.complete(null);
    await _scheduleFlush();
  }

  /// Flush and sends metrics.
  Future<void> _flush() async {
    final Iterable<int> flushableBucketKeys = _getFlushableBucketKeys();
    if (flushableBucketKeys.isEmpty) {
      _options.logger(SentryLevel.debug, 'Metrics: nothing to flush');
      return;
    }

    final Map<int, Iterable<Metric>> bucketsToFlush = {};
    int numMetrics = 0;

    for (int flushableBucketKey in flushableBucketKeys) {
      final Map<String, Metric>? bucket = buckets.remove(flushableBucketKey);
      if (bucket != null) {
        numMetrics += bucket.length;
        bucketsToFlush[flushableBucketKey] = bucket.values;
      }
    }

    if (numMetrics == 0) {
      _options.logger(SentryLevel.debug, 'Metrics: only empty buckets found');
      return;
    }

    _options.logger(SentryLevel.debug, 'Metrics: capture $numMetrics metrics');
    await Sentry.currentHub.captureMetrics(bucketsToFlush);
  }

  /// Return a list of bucket keys to flush.
  List<int> _getFlushableBucketKeys() {
    // Flushable buckets are all buckets with timestamp lower than the current
    // one (so now - rollupInSeconds), minus a random duration (flushShiftMs).
    final DateTime maxTimestampToFlush = _options.clock().subtract(Duration(
          seconds: _rollupInSeconds,
          milliseconds: _flushShiftMs,
        ));
    final int maxKeyToFlush = _getBucketKey(maxTimestampToFlush);

    // takeWhile works because we use a SplayTreeMap and keys are ordered.
    // toList() is needed because takeWhile is lazy and we want to remove items
    // from the buckets with these keys.
    return buckets.keys.takeWhile((value) => value <= maxKeyToFlush).toList();
  }

  /// The timestamp of the bucket, rounded down to the nearest RollupInSeconds.
  int _getBucketKey(DateTime timestamp) {
    final int seconds = timestamp.millisecondsSinceEpoch ~/ 1000;
    return (seconds ~/ _rollupInSeconds) * _rollupInSeconds;
  }

  void close() {
    _isClosed = true;
  }
}
