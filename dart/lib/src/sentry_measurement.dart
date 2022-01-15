class SentryMeasurement {
  SentryMeasurement(this.name, this.value);

  // Mobile / Desktop Vitals

  /// Amount of frames drawn during a transaction
  SentryMeasurement.totalFrames(this.value) : name = 'frames_total';

  /// Amount of slow frames drawn during a transaction.
  /// A slow frame is any frame longer than 1s / refreshrate.
  /// So for example any frame slower than 16ms for a refresh rate of 60hz.
  SentryMeasurement.slowFrames(this.value) : name = 'frames_slow';

  /// Amount of frozen frames drawn during a transaction.
  /// Typically defined as frames slower than 500ms.
  SentryMeasurement.frozenFrames(this.value) : name = 'frames_frozen';

  SentryMeasurement.coldAppStart(Duration duration)
      : assert(!duration.isNegative),
        name = 'app_start_cold',
        value = duration.inMilliseconds;

  SentryMeasurement.warmAppStart(Duration duration)
      : assert(!duration.isNegative),
        name = 'app_start_warm',
        value = duration.inMilliseconds;

  // Web Vitals

  SentryMeasurement.firstContentfulPaint(Duration duration)
      : assert(!duration.isNegative),
        name = 'fcp',
        value = duration.inMilliseconds;

  SentryMeasurement.firstPaint(Duration duration)
      : assert(!duration.isNegative),
        name = 'fp',
        value = duration.inMilliseconds;

  SentryMeasurement.timeToFirstByte(Duration duration)
      : assert(!duration.isNegative),
        name = 'ttfb',
        value = duration.inMilliseconds;

  final String name;
  final num value;

  Map<String, dynamic> toJson() {
    return <String, num>{
      'value': value,
    };
  }
}
