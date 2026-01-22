import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base class for metric data points sent to Sentry.
///
/// See [SentryCounterMetric], [SentryGaugeMetric], and [SentryDistributionMetric]
/// for concrete metric types.
abstract class SentryMetric {
  /// The metric type identifier (e.g., 'counter', 'gauge', 'distribution').
  final String type;

  /// The time when the metric was recorded.
  DateTime timestamp;

  /// The metric name, typically using dot notation (e.g., 'app.memory_usage').
  String name;

  /// The numeric value of the metric.
  num value;

  /// The trace ID from the current propagation context.
  SentryId traceId;

  /// The span ID of the active span when the metric was recorded.
  SpanId? spanId;

  /// The unit of measurement (e.g., 'millisecond', 'byte').
  ///
  /// See [SentryMetricUnit] for predefined unit constants.
  String? unit;

  /// Custom key-value pairs attached to the metric.
  Map<String, SentryAttribute> attributes;

  SentryMetric({
    required this.timestamp,
    required this.type,
    required this.name,
    required this.value,
    required this.traceId,
    this.spanId,
    this.unit,
    Map<String, SentryAttribute>? attributes,
  }) : attributes = attributes ?? {};

  @internal
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch / 1000.0,
      'type': type,
      'name': name,
      'value': value,
      'trace_id': traceId.toString(),
      if (spanId != null) 'span_id': spanId.toString(),
      if (unit != null) 'unit': unit,
      if (attributes.isNotEmpty)
        'attributes': attributes.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}

/// A metric that tracks the number of times an event occurs.
final class SentryCounterMetric extends SentryMetric {
  SentryCounterMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'counter');
}

/// A metric that tracks a value which can increase or decrease over time.
///
/// See [SentryMetricUnit] for predefined unit constants.
final class SentryGaugeMetric extends SentryMetric {
  SentryGaugeMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'gauge');
}

/// A metric that tracks the statistical distribution of a set of values.
///
/// See [SentryMetricUnit] for predefined unit constants.
final class SentryDistributionMetric extends SentryMetric {
  SentryDistributionMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'distribution');
}

/// String constants for metric units.
///
/// These constants represent the API names of measurement units that can be
/// used with metrics.
abstract final class SentryMetricUnit {
  /// Nanosecond, 10^-9 seconds.
  static const String nanosecond = 'nanosecond';

  /// Microsecond, 10^-6 seconds.
  static const String microsecond = 'microsecond';

  /// Millisecond, 10^-3 seconds.
  static const String millisecond = 'millisecond';

  /// Full second.
  static const String second = 'second';

  /// Minute, 60 seconds.
  static const String minute = 'minute';

  /// Hour, 3600 seconds.
  static const String hour = 'hour';

  /// Day, 86,400 seconds.
  static const String day = 'day';

  /// Week, 604,800 seconds.
  static const String week = 'week';

  /// Bit, corresponding to 1/8 of a byte.
  static const String bit = 'bit';

  /// Byte.
  static const String byte = 'byte';

  /// Kilobyte, 10^3 bytes.
  static const String kilobyte = 'kilobyte';

  /// Kibibyte, 2^10 bytes.
  static const String kibibyte = 'kibibyte';

  /// Megabyte, 10^6 bytes.
  static const String megabyte = 'megabyte';

  /// Mebibyte, 2^20 bytes.
  static const String mebibyte = 'mebibyte';

  /// Gigabyte, 10^9 bytes.
  static const String gigabyte = 'gigabyte';

  /// Gibibyte, 2^30 bytes.
  static const String gibibyte = 'gibibyte';

  /// Terabyte, 10^12 bytes.
  static const String terabyte = 'terabyte';

  /// Tebibyte, 2^40 bytes.
  static const String tebibyte = 'tebibyte';

  /// Petabyte, 10^15 bytes.
  static const String petabyte = 'petabyte';

  /// Pebibyte, 2^50 bytes.
  static const String pebibyte = 'pebibyte';

  /// Exabyte, 10^18 bytes.
  static const String exabyte = 'exabyte';

  /// Exbibyte, 2^60 bytes.
  static const String exbibyte = 'exbibyte';

  /// Floating point fraction of `1`.
  static const String ratio = 'ratio';

  /// Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`.
  static const String percent = 'percent';
}
