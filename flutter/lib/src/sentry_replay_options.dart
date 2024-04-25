import 'package:meta/meta.dart';

/// Configuration of the experimental replay feature.
class SentryReplayOptions {
  double? _sessionSampleRate;

  /// Indicates the percentage in which the replay for the session will be created. Specifying 0
  /// means never, 1.0 means always. The value needs to be >= 0.0 and <= 1.0 The default is null
  /// (disabled).
  double? get sessionSampleRate => _sessionSampleRate;

  /// Indicates the percentage in which the replay for the session will be created. Specifying 0
  /// means never, 1.0 means always. The value needs to be >= 0.0 and <= 1.0 The default is null
  /// (disabled).
  set sessionSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _sessionSampleRate = value;
  }

  double? _errorSampleRate;

  /// Indicates the percentage in which a 30 seconds replay will be send with error events.
  /// Specifying 0 means never, 1.0 means always. The value needs to be >= 0.0 and <= 1.0. The
  /// default is null (disabled).
  double? get errorSampleRate => _errorSampleRate;

  /// Indicates the percentage in which a 30 seconds replay will be send with error events.
  /// Specifying 0 means never, 1.0 means always. The value needs to be >= 0.0 and <= 1.0. The
  /// default is null (disabled).
  set errorSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _errorSampleRate = value;
  }

  // TODO implement in flutter
  // /// Redact all text content. Draws a rectangle of text bounds with text color on top. By default
  // /// only views extending TextView are redacted.
  // /// Default is enabled.
  // bool redactAllText = true;

  // TODO implement in flutter
  // /// Redact all image content. Draws a rectangle of image bounds with image's dominant color on top.
  // /// By default only views extending ImageView with BitmapDrawable or custom Drawable type are
  // /// redacted. ColorDrawable, InsetDrawable, VectorDrawable are all considered non-PII, as they come
  // /// from the apk.
  // /// Default is enabled.
  // bool redactAllImages = true;

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((errorSampleRate ?? 0) > 0);
}
