class SentryMeasurement {
  SentryMeasurement(this.name, this.value);

  SentryMeasurement.totalFrames(this.value) : name = 'frames_total';
  SentryMeasurement.slowFrames(this.value) : name = 'frames_slow';
  SentryMeasurement.frozenFrames(this.value) : name = 'frames_frozen';

  final String name;
  final double value;

  Map<String, dynamic> toJson() {
    return <String, double>{
      'value': value,
    };
  }
}
