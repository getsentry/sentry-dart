import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry.dart';

final RegExp unitRegex = RegExp('[^\\w]+');
final RegExp nameRegex = RegExp('[^\\w-.]+');
final RegExp tagKeyRegex = RegExp('[^\\w-./]+');

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

  factory Metric.fromType({
    required final MetricType type,
    required final String key,
    required final num value,
    required final SentryMeasurementUnit unit,
    required final Map<String, String> tags,
  }) {
    switch (type) {
      case MetricType.counter:
        return CounterMetric._(value: value, key: key, unit: unit, tags: tags);
      case MetricType.gauge:
        return GaugeMetric._(value: value, key: key, unit: unit, tags: tags);
      case MetricType.set:
        return SetMetric._(value: value, key: key, unit: unit, tags: tags);
      case MetricType.distribution:
        return DistributionMetric._(
            value: value, key: key, unit: unit, tags: tags);
    }
  }

  /// Add a value to the metric.
  add(num value);

  /// Return the weight of the current metric.
  int getWeight();

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
    buffer.write(_sanitizeName(key));
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
              '${_sanitizeTagKey(tag.key)}:${_sanitizeTagValue(tag.value)}')
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

  /// Return a key created by [key], [type] and [unit].
  /// This key should be used to aggregate the metric locally in a span.
  String getSpanAggregationKey() => '${type.statsdType}:$key@${unit.name}';

  /// Remove forbidden characters from the metric key and tag key.
  String _sanitizeName(String input) => input.replaceAll(nameRegex, '_');

  /// Remove forbidden characters from the tag value.
  String _sanitizeTagKey(String input) => input.replaceAll(tagKeyRegex, '');

  /// Remove forbidden characters from the metric unit.
  String _sanitizeUnit(String input) => input.replaceAll(unitRegex, '');

  String _sanitizeTagValue(String input) {
    // see https://develop.sentry.dev/sdk/metrics/#tag-values-replacement-map
    // Line feed       -> \n
    // Carriage return -> \r
    // Tab             -> \t
    // Backslash       -> \\
    // Pipe            -> \\u{7c}
    // Comma           -> \\u{2c}
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '\n') {
        buffer.write("\\n");
      } else if (ch == '\r') {
        buffer.write("\\r");
      } else if (ch == '\t') {
        buffer.write("\\t");
      } else if (ch == '\\') {
        buffer.write("\\\\");
      } else if (ch == '|') {
        buffer.write("\\u{7c}");
      } else if (ch == ',') {
        buffer.write("\\u{2c}");
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}

/// Metric [MetricType.counter] that tracks a value that can only be incremented.
@internal
class CounterMetric extends Metric {
  num value;

  CounterMetric._({
    required this.value,
    required super.key,
    required super.unit,
    required super.tags,
  }) : super(type: MetricType.counter);

  @override
  add(num value) => this.value += value;

  @override
  Iterable<Object> _serializeValue() => [value];

  @override
  int getWeight() => 1;
}

/// Metric [MetricType.gauge] that tracks a value that can go up and down.
@internal
class GaugeMetric extends Metric {
  num _last;
  num _minimum;
  num _maximum;
  num _sum;
  int _count;

  GaugeMetric._({
    required num value,
    required super.key,
    required super.unit,
    required super.tags,
  })  : _last = value,
        _minimum = value,
        _maximum = value,
        _sum = value,
        _count = 1,
        super(type: MetricType.gauge);

  @override
  add(num value) {
    _last = value;
    _minimum = min(_minimum, value);
    _maximum = max(_maximum, value);
    _sum += value;
    _count++;
  }

  @override
  Iterable<Object> _serializeValue() =>
      [_last, _minimum, _maximum, _sum, _count];

  @override
  int getWeight() => 5;

  @visibleForTesting
  num get last => _last;
  num get minimum => _minimum;
  num get maximum => _maximum;
  num get sum => _sum;
  int get count => _count;
}

/// Metric [MetricType.set] that tracks a set of values on which you can perform
/// aggregations such as count_unique.
@internal
class SetMetric extends Metric {
  final Set<int> _values = {};

  SetMetric._(
      {required num value,
      required super.key,
      required super.unit,
      required super.tags})
      : super(type: MetricType.set) {
    add(value);
  }

  @override
  add(num value) => _values.add(value.toInt());

  @override
  Iterable<Object> _serializeValue() => _values;

  @override
  int getWeight() => _values.length;

  @visibleForTesting
  Set<num> get values => _values;
}

/// Metric [MetricType.distribution] that tracks a list of values.
@internal
class DistributionMetric extends Metric {
  final List<num> _values = [];

  DistributionMetric._(
      {required num value,
      required super.key,
      required super.unit,
      required super.tags})
      : super(type: MetricType.distribution) {
    add(value);
  }

  @override
  add(num value) => _values.add(value);

  @override
  Iterable<Object> _serializeValue() => _values;

  @override
  int getWeight() => _values.length;

  @visibleForTesting
  List<num> get values => _values;
}

/// The metric type and its associated statsd encoded value.
@internal
enum MetricType {
  counter('c'),
  gauge('g'),
  distribution('d'),
  set('s');

  final String statsdType;

  const MetricType(this.statsdType);
}
