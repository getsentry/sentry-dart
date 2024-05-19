import 'dart:async';
import 'dart:convert';
import '../../sentry.dart';
import '../utils/crc32_utils.dart';
import 'metric.dart';

/// Public APIs to emit Sentry metrics.
class MetricsApi {
  MetricsApi({Hub? hub}) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  /// Emits a Counter metric, identified by [key], increasing it by [value].
  /// Counters track a value that can only be incremented.
  /// You can set the [unit] and the optional [tags] to associate to the metric.
  void increment(final String key,
      {final double value = 1.0,
      final SentryMeasurementUnit? unit,
      final Map<String, String>? tags}) {
    _hub.metricsAggregator?.emit(
      MetricType.counter,
      key,
      value,
      unit ?? SentryMeasurementUnit.none,
      _enrichWithDefaultTags(tags),
    );
  }

  /// Emits a Gauge metric, identified by [key], adding [value] to it.
  /// Gauges track a value that can go up and down.
  /// You can set the [unit] and the optional [tags] to associate to the metric.
  void gauge(final String key,
      {required final double value,
      final SentryMeasurementUnit? unit,
      final Map<String, String>? tags}) {
    _hub.metricsAggregator?.emit(
      MetricType.gauge,
      key,
      value,
      unit ?? SentryMeasurementUnit.none,
      _enrichWithDefaultTags(tags),
    );
  }

  /// Emits a Distribution metric, identified by [key], adding [value] to it.
  /// Distributions track a list of values.
  /// You can set the [unit] and the optional [tags] to associate to the metric.
  void distribution(final String key,
      {required final double value,
      final SentryMeasurementUnit? unit,
      final Map<String, String>? tags}) {
    _hub.metricsAggregator?.emit(
      MetricType.distribution,
      key,
      value,
      unit ?? SentryMeasurementUnit.none,
      _enrichWithDefaultTags(tags),
    );
  }

  /// Emits a Set metric, identified by [key], adding [value] or the CRC32
  ///  checksum of [stringValue] to it.
  /// Providing both [value] and [stringValue] adds both values to the metric.
  /// Sets track a set of values to perform aggregations such as count_unique.
  /// You can set the [unit] and the optional [tags] to associate to the metric.
  void set(final String key,
      {final int? value,
      final String? stringValue,
      final SentryMeasurementUnit? unit,
      final Map<String, String>? tags}) {
    if (value != null) {
      _hub.metricsAggregator?.emit(
        MetricType.set,
        key,
        value,
        unit ?? SentryMeasurementUnit.none,
        _enrichWithDefaultTags(tags),
      );
    }
    if (stringValue != null && stringValue.isNotEmpty) {
      final intValue = Crc32Utils.getCrc32(utf8.encode(stringValue));

      _hub.metricsAggregator?.emit(
        MetricType.set,
        key,
        intValue,
        unit ?? SentryMeasurementUnit.none,
        _enrichWithDefaultTags(tags),
      );
    }
    if (value == null && (stringValue == null || stringValue.isEmpty)) {
      _hub.options.logger(
          SentryLevel.info, 'No value provided. No metric will be emitted.');
    }
  }

  /// Enrich user tags adding <a href=https://develop.sentry.dev/delightful-developer-metrics/sending-metrics-sdk/#automatic-tags-extraction>default tags</a>
  ///
  /// Currently adds release, environment and transaction.
  Map<String, String> _enrichWithDefaultTags(Map<String, String>? userTags) {
    // We create another map, in case the userTags is unmodifiable.
    final Map<String, String> tags = Map.from(userTags ?? {});
    if (!_hub.options.enableDefaultTagsForMetrics) {
      return tags;
    }
    // Enrich tags with default values (without overwriting user values)
    _putIfAbsentIfNotNull(tags, 'release', _hub.options.release);
    _putIfAbsentIfNotNull(tags, 'environment', _hub.options.environment);
    _putIfAbsentIfNotNull(tags, 'transaction', _hub.scope.transaction);
    return tags;
  }

  /// Call [map.putIfAbsent] with [key] and [value] if [value] is not null.
  _putIfAbsentIfNotNull<K, V>(Map<K, V> map, K key, V? value) {
    if (value != null) {
      map.putIfAbsent(key, () => value);
    }
  }

  /// Emits a Distribution metric, identified by [key], with the time it takes
  /// to run [function].
  /// You can set the [unit] and the optional [tags] to associate to the metric.
  void timing(final String key,
      {required FutureOr<void> Function() function,
      final DurationSentryMeasurementUnit unit =
          DurationSentryMeasurementUnit.second,
      final Map<String, String>? tags}) async {
    // Start a span for the metric
    final span = _hub.getSpan()?.startChild('metric.timing', description: key);
    // Set the user tags to the span as well
    if (span != null && tags != null) {
      for (final entry in tags.entries) {
        span.setTag(entry.key, entry.value);
      }
    }
    final before = _hub.options.clock();
    try {
      if (function is Future<void> Function()) {
        await function();
      } else {
        function();
      }
    } finally {
      final after = _hub.options.clock();
      Duration duration = after.difference(before);
      // If we have a span, we use its duration as value for the emitted metric
      if (span != null) {
        await span.finish();
        duration =
            span.endTimestamp?.difference(span.startTimestamp) ?? duration;
      }
      final value = _convertMicrosTo(unit, duration.inMicroseconds);

      _hub.metricsAggregator?.emit(
        MetricType.distribution,
        key,
        value,
        unit,
        _enrichWithDefaultTags(tags),
        localMetricsAggregator: span?.localMetricsAggregator,
      );
    }
  }

  double _convertMicrosTo(
      final DurationSentryMeasurementUnit unit, final int micros) {
    switch (unit) {
      case DurationSentryMeasurementUnit.nanoSecond:
        return micros * 1000;
      case DurationSentryMeasurementUnit.microSecond:
        return micros.toDouble();
      case DurationSentryMeasurementUnit.milliSecond:
        return micros / 1000.0;
      case DurationSentryMeasurementUnit.second:
        return micros / 1000000.0;
      case DurationSentryMeasurementUnit.minute:
        return micros / 60000000.0;
      case DurationSentryMeasurementUnit.hour:
        return micros / 3600000000.0;
      case DurationSentryMeasurementUnit.day:
        return micros / 86400000000.0;
      case DurationSentryMeasurementUnit.week:
        return micros / 86400000000.0 / 7.0;
    }
  }
}
