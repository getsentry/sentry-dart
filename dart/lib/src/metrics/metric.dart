import 'package:meta/meta.dart';

import '../../sentry.dart';

final RegExp forbiddenKeyCharsRegex = RegExp('[^a-zA-Z0-9_/.-]+');
final RegExp forbiddenValueCharsRegex =
    RegExp('[^\\w\\d\\s_:/@\\.\\{\\}\\[\\]\$-]+');
final RegExp forbiddenUnitCharsRegex = RegExp('[^a-zA-Z0-9_/.]+');

/// Base class for metrics.
/// Each metric is identified by a [key]. Its [type] describes its behaviour.
/// A [unit] (defaults to [SentryMeasurementUnit.none]) describes the values
/// being tracked. Optional [tags] can be added. The [timestamp] is the time
/// when the metric was emitted.
@internal
abstract class Metric {
  final MetricType type;
  final String key;
  final SentryMeasurementUnit unit;
  final Map<String, String> tags;

  Metric({
    required this.type,
    required this.key,
    required this.unit,
    required this.tags,
  });

  /// Add a value to the metric.
  add(double value);

  /// Serialize the value into a list of Objects to be converted into a String.
  Iterable<Object> _serializeValue();

  /// Encodes the metric in the statsd format
  /// See <a href="https://github.com/statsd/statsd#usage">github.com/statsd/statsd#usage</a> and
  /// <a href="https://getsentry.github.io/relay/relay_metrics/index.html">getsentry.github.io/relay/relay_metrics/index.html</a>
  /// for more details about the format.
  ///
  /// Example format: key@none:1|c|#myTag:myValue|T1710844170
  /// key@unit:value1:value2|type|#tagKey1:tagValue1,tagKey2:tagValue2,|TbucketKey
  ///
  /// [bucketKey] is the key of the metric bucket that will be sent to Sentry,
  ///  and it's appended at the end of the encoded metric.
  String encodeToStatsd(int bucketKey) {
    final buffer = StringBuffer();
    buffer.write(_normalizeKey(key));
    buffer.write("@");

    final sanitizeUnitName = _sanitizeUnit(unit.name);
    buffer.write(sanitizeUnitName);

    for (final value in _serializeValue()) {
      buffer.write(":");
      buffer.write(value.toString());
    }

    buffer.write("|");
    buffer.write(type.statsdType);

    if (tags.isNotEmpty) {
      buffer.write("|#");
      final serializedTags = tags.entries
          .map((tag) =>
              '${_normalizeKey(tag.key)}:${_normalizeTagValue(tag.value)}')
          .join(',');
      buffer.write(serializedTags);
    }

    buffer.write("|T");
    buffer.write(bucketKey);

    return buffer.toString();
  }

  /// Return a key created by [key], [type], [unit] and [tags].
  /// This key should be used to retrieve the metric to update in aggregation.
  String getCompositeKey() {
    final String serializedTags = tags.entries.map((e) {
      // We escape the ',' from the key and the value, as we will join the tags
      //  with a ',' to create the composite key.
      String escapedKey = e.key.replaceAll(',', '\\,');
      String escapedValue = e.value.replaceAll(',', '\\,');
      return '$escapedKey=$escapedValue';
    }).join(',');

    return ('${type.statsdType}_${key}_${unit.name}_$serializedTags');
  }

  /// Remove forbidden characters from the metric key and tag key.
  String _normalizeKey(String input) =>
      input.replaceAll(forbiddenKeyCharsRegex, '_');

  /// Remove forbidden characters from the tag value.
  String _normalizeTagValue(String input) =>
      input.replaceAll(forbiddenValueCharsRegex, '');

  /// Remove forbidden characters from the metric unit.
  String _sanitizeUnit(String input) =>
      input.replaceAll(forbiddenUnitCharsRegex, '_');
}

@internal

/// Metric [MetricType.counter] that tracks a value that can only be incremented.
class CounterMetric extends Metric {
  double value;

  CounterMetric({
    required this.value,
    required super.key,
    required super.unit,
    required super.tags,
  }) : super(type: MetricType.counter);

  @override
  add(double value) => this.value += value;

  @override
  Iterable<Object> _serializeValue() => [value];
}

@internal

/// The metric type and its associated statsd encoded value.
enum MetricType {
  counter('c');

  final String statsdType;

  const MetricType(this.statsdType);
}
