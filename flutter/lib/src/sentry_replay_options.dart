import 'package:meta/meta.dart';

import 'replay/replay_quality.dart';

/// Configuration of the replay feature.
class SentryReplayOptions {
  double? _sessionSampleRate;

  /// A percentage of sessions in which a replay will be created.
  /// The value needs to be >= 0.0 and <= 1.0.
  /// Specifying 0 means none, 1.0 means 100 %. Defaults to null (disabled).
  double? get sessionSampleRate => _sessionSampleRate;
  set sessionSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _sessionSampleRate = value;
  }

  double? _onErrorSampleRate;

  /// A percentage of errors that will be accompanied by a 30 seconds replay.
  /// The value needs to be >= 0.0 and <= 1.0.
  /// Specifying 0 means none, 1.0 means 100 %. Defaults to null (disabled).
  double? get onErrorSampleRate => _onErrorSampleRate;
  set onErrorSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _onErrorSampleRate = value;
  }

  ///  Defines the image quality of the session replay. The higher the quality,
  ///  the more accurate the replay will be, but also more data to transfer and
  /// more CPU load, defaults to MEDIUM.
  var quality = SentryReplayQuality.medium;

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
}
