class SentryMeasurement {
  SentryMeasurement(this.name, this.value);

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

  final String name;
  final num value;

  Map<String, dynamic> toJson() {
    return <String, num>{
      'value': value,
    };
  }
}
