import 'package:meta/meta.dart';

/// Configuration of the experimental replay feature.
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

  /// Redact all text content. Draws a rectangle of text bounds with text color
  /// on top. Currently, only [Text] and [EditableText] Widgets are redacted.
  /// Default is enabled.
  var redactAllText = true;

  /// Redact all image content. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are redacted.
  /// Default is enabled.
  var redactAllImages = true;

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
}
