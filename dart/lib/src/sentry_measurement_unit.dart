enum SentryMeasurementUnit {
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

  /// Untyped value without a unit.
  none,
}

extension SentryMeasurementUnitExtension on SentryMeasurementUnit {
  String toStringValue() {
    switch (this) {
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
      case SentryMeasurementUnit.none:
        return 'none';
    }
  }
}
