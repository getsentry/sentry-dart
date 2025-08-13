/// The unit of measurement of a metric value.
/// Units augment metric values by giving them a magnitude and semantics.
/// Units and their precisions are uniquely represented by a string identifier.
abstract class SentryMeasurementUnit {
  static final none = NoneSentryMeasurementUnit();
  String get name;
}

extension SentryMeasurementUnitExtension on SentryMeasurementUnit {
  String toStringValue() {
    return name;
  }
}

enum DurationSentryMeasurementUnit implements SentryMeasurementUnit {
  /// Nanosecond (`"nanosecond"`), 10^-9 seconds.
  nanoSecond('nanosecond'),

  /// Microsecond (`"microsecond"`), 10^-6 seconds.
  microSecond('microsecond'),

  /// Millisecond (`"millisecond"`), 10^-3 seconds.
  milliSecond('millisecond'),

  /// Full second (`"second"`).
  second('second'),

  /// Minute (`"minute"`), 60 seconds.
  minute('minute'),

  /// Hour (`"hour"`), 3600 seconds.
  hour('hour'),

  /// Day (`"day"`), 86,400 seconds.
  day('day'),

  /// Week (`"week"`), 604,800 seconds.
  week('week');

  const DurationSentryMeasurementUnit(this.name);

  @override
  final String name;
}

enum InformationSentryMeasurementUnit implements SentryMeasurementUnit {
  /// Bit (`"bit"`), corresponding to 1/8 of a byte.
  bit("bit"),

  /// Byte (`"byte"`).
  byte('byte'),

  /// Kilobyte (`"kilobyte"`), 10^3 bytes.
  kiloByte('kilobyte'),

  /// Kibibyte (`"kibibyte"`), 2^10 bytes.
  kibiByte('kibibyte'),

  /// Megabyte (`"megabyte"`), 10^6 bytes.
  megaByte('megabyte'),

  /// Mebibyte (`"mebibyte"`), 2^20 bytes.
  mebiByte('mebibyte'),

  /// Gigabyte (`"gigabyte"`), 10^9 bytes.
  gigaByte('gigabyte'),

  /// Gibibyte (`"gibibyte"`), 2^30 bytes.
  gibiByte('gibibyte'),

  /// Terabyte (`"terabyte"`), 10^12 bytes.
  teraByte('terabyte'),

  /// Tebibyte (`"tebibyte"`), 2^40 bytes.
  tebiByte('tebibyte'),

  /// Petabyte (`"petabyte"`), 10^15 bytes.
  petaByte('petabyte'),

  /// Pebibyte (`"pebibyte"`), 2^50 bytes.
  pebiByte('pebibyte'),

  /// Exabyte (`"exabyte"`), 10^18 bytes.
  exaByte('exabyte'),

  /// Exbibyte (`"exbibyte"`), 2^60 bytes.
  exbiByte('exbibyte');

  const InformationSentryMeasurementUnit(this.name);

  @override
  final String name;
}

enum FractionSentryMeasurementUnit implements SentryMeasurementUnit {
  /// Floating point fraction of `1`.
  ratio('ratio'),

  /// Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`.
  percent('percent');

  const FractionSentryMeasurementUnit(this.name);

  @override
  final String name;
}

/// Custom units without builtin conversion. No formatting will be applied to
/// the measurement value in the Sentry product, and the value with the unit
/// will be shown as is.
class CustomSentryMeasurementUnit implements SentryMeasurementUnit {
  CustomSentryMeasurementUnit(this.name);

  @override
  final String name;
}

/// Untyped value.
class NoneSentryMeasurementUnit implements SentryMeasurementUnit {
  @override
  String get name => 'none';
}
