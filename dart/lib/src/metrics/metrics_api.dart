import 'dart:convert';
import '../../sentry.dart';
import '../utils/crc32_utils.dart';
import 'metric.dart';

/// Public APIs to emit Sentry metrics.
class MetricsApi {
  MetricsApi({Hub? hub}) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  /// Emits a Counter metric, identified by [key], increasing it by [value].
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

  /// Emits a Gauge metric, identified by [key], adding [value] to it.
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
        value.toDouble(),
        unit ?? SentryMeasurementUnit.none,
        _enrichWithDefaultTags(tags),
      );
    }
    if (stringValue != null) {
      final int intValue = Crc32Utils.getCrc32(utf8.encode(stringValue));

      _hub.metricsAggregator?.emit(
        MetricType.set,
        key,
        intValue.toDouble(),
        unit ?? SentryMeasurementUnit.none,
        _enrichWithDefaultTags(tags),
      );
    }
    if (value == null && stringValue == null) {
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
}
