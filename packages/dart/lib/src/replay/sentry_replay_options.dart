import '../http_client/sentry_http_client.dart';

/// Configuration for data captured for Session Replay.
class SentryReplayOptions {
  /// List of strings/regex controlling for which outgoing requests made
  /// with [SentryHttpClient] headers/bodies are captured, to be shown
  /// alongside network spans in Session Replay.
  ///
  /// Currently only forwarded to Session Replay on Android; on other
  /// platforms the data is captured but not yet surfaced in the replay.
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
}
