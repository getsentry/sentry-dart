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
  nanoSecond(name: 'nanosecond'),

  /// Microsecond (`"microsecond"`), 10^-6 seconds.
  microSecond(name: 'microsecond'),

  /// Millisecond (`"millisecond"`), 10^-3 seconds.
  milliSecond(name: 'millisecond'),

  /// Full second (`"second"`).
  second(name: 'second'),

  /// Minute (`"minute"`), 60 seconds.
  minute(name: 'minute'),

  /// Hour (`"hour"`), 3600 seconds.
  hour(name: 'hour'),

  /// Day (`"day"`), 86,400 seconds.
  day(name: 'day'),

  /// Week (`"week"`), 604,800 seconds.
  week(name: 'week');

  const DurationSentryMeasurementUnit({required this.name});

  @override
  final String name;
}

enum InformationSentryMeasurementUnit implements SentryMeasurementUnit {
  /// Bit (`"bit"`), corresponding to 1/8 of a byte.
  bit(name: "bit"),

  /// Byte (`"byte"`).
  byte(name: 'byte'),

  /// Kilobyte (`"kilobyte"`), 10^3 bytes.
  kiloByte(name: 'kilobyte'),

  /// Kibibyte (`"kibibyte"`), 2^10 bytes.
  kibiByte(name: 'kibibyte'),

  /// Megabyte (`"megabyte"`), 10^6 bytes.
  megaByte(name: 'megabyte'),

  /// Mebibyte (`"mebibyte"`), 2^20 bytes.
  mebiByte(name: 'mebibyte'),

  /// Gigabyte (`"gigabyte"`), 10^9 bytes.
  gigaByte(name: 'gigabyte'),

  /// Gibibyte (`"gibibyte"`), 2^30 bytes.
  gibiByte(name: 'gibibyte'),

  /// Terabyte (`"terabyte"`), 10^12 bytes.
  teraByte(name: 'terabyte'),

  /// Tebibyte (`"tebibyte"`), 2^40 bytes.
  tebiByte(name: 'tebibyte'),

  /// Petabyte (`"petabyte"`), 10^15 bytes.
  petaByte(name: 'petabyte'),

  /// Pebibyte (`"pebibyte"`), 2^50 bytes.
  pebiByte(name: 'pebibyte'),

  /// Exabyte (`"exabyte"`), 10^18 bytes.
  exaByte(name: 'exabyte'),

  /// Exbibyte (`"exbibyte"`), 2^60 bytes.
  exbiByte(name: 'exbibyte');

  const InformationSentryMeasurementUnit({required this.name});

  @override
  final String name;
}

enum FractionSentryMeasurementUnit implements SentryMeasurementUnit {
  /// Floating point fraction of `1`.
  ratio(name: 'ratio'),

  /// Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`.
  percent(name: 'percent');

  const FractionSentryMeasurementUnit({required this.name});

  @override
  final String name;
}

/// Custom units without builtin conversion. No formatting will be applied to
/// the measurement value in the Sentry product, and the value with the unit
/// will be shown as is.
class CustomSentryMeasurementUnit implements SentryMeasurementUnit {
  final String _name;

  CustomSentryMeasurementUnit(this._name);

  @override
  String get name => _name;
}

/// Untyped value.
class NoneSentryMeasurementUnit implements SentryMeasurementUnit {
  @override
  String get name => 'none';
}
