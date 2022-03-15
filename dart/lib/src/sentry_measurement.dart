class SentryMeasurement {
  SentryMeasurement(this.name, this.value);

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
