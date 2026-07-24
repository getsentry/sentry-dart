import 'package:meta/meta.dart';

import 'replay/replay_quality.dart';

/// Configuration of the replay feature.
class SentryReplayOptions {
  /// List of strings/regex controlling for which outgoing requests made
  /// with `SentryHttpClient` headers/bodies are captured, to be shown
  /// alongside network spans in Session Replay.
  ///
  /// Empty by default, meaning no request is captured. Request/response
  /// bodies may contain PII — review this list carefully before adding
  /// entries.
  ///
  /// This data is attached to HTTP breadcrumbs, so `recordHttpBreadcrumbs`
  /// must also be enabled (the default) for this option to have any effect.
  final List<String> networkDetailAllowUrls = [];

  /// List of strings/regex excluded from [networkDetailAllowUrls].
  ///
  /// A URL matching both [networkDetailAllowUrls] and this list is
  /// excluded.
  final List<String> networkDetailDenyUrls = [];

  /// Whether request/response bodies are captured for URLs matching
  /// [networkDetailAllowUrls].
  ///
  /// Only takes effect when `sendDefaultPii` is also enabled, since bodies
  /// commonly contain PII.
  ///
  /// Only text, JSON, and form-urlencoded bodies are captured; binary
  /// bodies are skipped and bodies are truncated at 150KB.
  bool networkCaptureBodies = true;

  /// Additional request header names to capture for URLs matching
  /// [networkDetailAllowUrls].
  ///
  /// `Content-Type`, `Content-Length`, and `Accept` are always captured.
  /// Any other header only takes effect when `sendDefaultPii` is also
  /// enabled, since headers such as `Authorization` or `Cookie` may contain
  /// PII.
  final List<String> networkRequestHeaders = [];

  /// Additional response header names to capture for URLs matching
  /// [networkDetailAllowUrls].
  ///
  /// `Content-Type`, `Content-Length`, and `Accept` are always captured.
  /// Any other header only takes effect when `sendDefaultPii` is also
  /// enabled, since headers such as `Set-Cookie` may contain PII.
  final List<String> networkResponseHeaders = [];

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
