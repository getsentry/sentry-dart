/// The unit of measurement of a metric value.
/// Units augment metric values by giving them a magnitude and semantics.
/// Units and their precisions are uniquely represented by a string identifier.
///
/// This is a singe enum because Enhanced Enums in Dart is only available
/// in newer versions.
enum SentryMeasurementUnit {
  /// Duration units

  /// Nanosecond (`"nanosecond"`), 10^-9 seconds.
  nanoSecond,

  /// Microsecond (`"microsecond"`), 10^-6 seconds.
  microSecond,

  /// Millisecond (`"millisecond"`), 10^-3 seconds.
  milliSecond,

  /// Full second (`"second"`).
  second,

  /// Minute (`"minute"`), 60 seconds.
  minute,

  /// Hour (`"hour"`), 3600 seconds.
  hour,

  /// Day (`"day"`), 86,400 seconds.
  day,

  /// Week (`"week"`), 604,800 seconds.
  week,

  /// Information units

  /// Bit (`"bit"`), corresponding to 1/8 of a byte.
  bit,

  /// Byte (`"byte"`).
  byte,

  /// Kilobyte (`"kilobyte"`), 10^3 bytes.
  kiloByte,

  /// Kibibyte (`"kibibyte"`), 2^10 bytes.
  kibiByte,

  /// Megabyte (`"megabyte"`), 10^6 bytes.
  megaByte,

  /// Mebibyte (`"mebibyte"`), 2^20 bytes.
  mebiByte,

  /// Gigabyte (`"gigabyte"`), 10^9 bytes.
  gigaByte,

  /// Gibibyte (`"gibibyte"`), 2^30 bytes.
  gibiByte,

  /// Terabyte (`"terabyte"`), 10^12 bytes.
  teraByte,

  /// Tebibyte (`"tebibyte"`), 2^40 bytes.
  tebiByte,

  /// Petabyte (`"petabyte"`), 10^15 bytes.
  petaByte,

  /// Pebibyte (`"pebibyte"`), 2^50 bytes.
  pebiByte,

  /// Exabyte (`"exabyte"`), 10^18 bytes.
  exaByte,

  /// Exbibyte (`"exbibyte"`), 2^60 bytes.
  exbiByte,

  /// Fraction units

  /// Floating point fraction of `1`.
  ratio,

  /// Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`.
  percent,

  /// Untyped value without a unit.
  none,
}

extension SentryMeasurementUnitExtension on SentryMeasurementUnit {
  String toStringValue() {
    switch (this) {
      // Duration units
      case SentryMeasurementUnit.nanoSecond:
        return 'nanosecond';
      case SentryMeasurementUnit.microSecond:
        return 'microsecond';
      case SentryMeasurementUnit.milliSecond:
        return 'millisecond';
      case SentryMeasurementUnit.second:
        return 'second';
      case SentryMeasurementUnit.minute:
        return 'minute';
      case SentryMeasurementUnit.hour:
        return 'hour';
      case SentryMeasurementUnit.day:
        return 'day';
      case SentryMeasurementUnit.week:
        return 'week';

      // Information units
      case SentryMeasurementUnit.bit:
        return 'bit';
      case SentryMeasurementUnit.byte:
        return 'byte';
      case SentryMeasurementUnit.kiloByte:
        return 'kilobyte';
      case SentryMeasurementUnit.kibiByte:
        return 'kibibyte';
      case SentryMeasurementUnit.megaByte:
        return 'megabyte';
      case SentryMeasurementUnit.mebiByte:
        return 'mebibyte';
      case SentryMeasurementUnit.gigaByte:
        return 'gigabyte';
      case SentryMeasurementUnit.gibiByte:
        return 'gibibyte';
      case SentryMeasurementUnit.teraByte:
        return 'terabyte';
      case SentryMeasurementUnit.tebiByte:
        return 'tebibyte';
      case SentryMeasurementUnit.petaByte:
        return 'petabyte';
      case SentryMeasurementUnit.pebiByte:
        return 'pebibyte';
      case SentryMeasurementUnit.exaByte:
        return 'exabyte';
      case SentryMeasurementUnit.exbiByte:
        return 'exbibyte';

      // Fraction units
      case SentryMeasurementUnit.ratio:
        return 'ratio';
      case SentryMeasurementUnit.percent:
        return 'percent';

      // Untyped value
      case SentryMeasurementUnit.none:
        return 'none';
    }
  }
}
