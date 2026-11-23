import 'package:meta/meta.dart';

/// Experimental continuous profiling for iOS and macOS.
@experimental
class SentryProfilingOptions {
  double _sessionSampleRate = 0;

  /// Fraction of foreground sessions eligible for profiling, from 0 to 1.
  /// Defaults to 0 (disabled). Cocoa makes the sampling decision.
  double get sessionSampleRate => _sessionSampleRate;
  set sessionSampleRate(double value) {
    if (!(value >= 0 && value <= 1)) {
      throw ArgumentError.value(
        value,
        'sessionSampleRate',
        'Must be between 0 and 1',
      );
    }
    _sessionSampleRate = value;
  }

  /// Start profiling at launch for sampled sessions. Defaults to false.
  ///
  /// Cocoa saves the configuration for the next launch. Call
  /// `SentryFlutter.stopProfiler()` when the startup work finishes.
  bool profileAppStarts = false;
}
