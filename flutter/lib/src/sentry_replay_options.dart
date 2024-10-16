import 'package:meta/meta.dart';

import 'sentry_screenshot_options.dart';

/// Configuration of the experimental replay feature.
@experimental
class SentryReplayOptions extends SentryScreenshotOptions {
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

  @Deprecated('Use maskAllText instead')
  bool get redactAllText => maskAllText;
  set redactAllText(bool value) => maskAllText = value;

  @Deprecated('Use maskAllImages instead')
  bool get redactAllImages => maskAllImages;
  set redactAllImages(bool value) => maskAllImages = value;

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
}
