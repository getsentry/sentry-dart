import 'platform_checker.dart';

/// Spotlight configuration class.
class Spotlight {
  /// Whether to enable Spotlight for local development.
  bool enabled;

  /// The Spotlight Sidecar URL.
  /// Defaults to http://10.0.2.2:8969/stream due to Emulator on Android.
  /// Otherwise defaults to http://localhost:8969/stream.
  String url;

  Spotlight({required this.enabled, String? url})
      : url = url ?? _defaultSpotlightUrl();
}

String _defaultSpotlightUrl() {
  return (PlatformChecker().platform.isAndroid
      ? 'http://10.0.2.2:8969/stream'
      : 'http://localhost:8969/stream');
}
