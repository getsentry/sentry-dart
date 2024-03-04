import '../sentry_flutter.dart';

extension SentryFlutterMeasurement on SentryMeasurement {
  /// Duration of the time to initial display in milliseconds
  static SentryMeasurement timeToInitialDisplay(Duration duration) {
    assert(!duration.isNegative);
    return SentryMeasurement(
      'time_to_initial_display',
      duration.inMilliseconds.toDouble(),
      unit: DurationSentryMeasurementUnit.milliSecond,
    );
  }

  /// Duration of the time to full display in milliseconds
  static SentryMeasurement timeToFullDisplay(Duration duration) {
    assert(!duration.isNegative);
    return SentryMeasurement(
      'time_to_full_display',
      duration.inMilliseconds.toDouble(),
      unit: DurationSentryMeasurementUnit.milliSecond,
    );
  }
}
