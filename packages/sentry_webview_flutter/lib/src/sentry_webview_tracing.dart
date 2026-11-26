import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'internal_logger.dart';

/// Connects a Flutter trace to the browser SDK running inside a WebView.
abstract final class SentryWebViewTracing {
  static const _channel = MethodChannel('sentry_flutter/webview_tracing');

  /// Installs the current trace for future top-level HTTPS loads on [controller].
  ///
  /// Await before navigation. Each call replaces the previous trace and host
  /// list. An empty list removes propagation. Only include hosts whose scripts
  /// you trust. Host matching follows [SentryWebViewScript.build].
  ///
  /// On Apple platforms call this after changing zoom or removing a JavaScript
  /// channel, as those operations can reset the WebView's document-start scripts.
  /// Returns true when the new script was installed.
  static Future<bool> addTracePropagation(
    WebViewController controller, {
    required List<String> allowedHosts,
  }) async {
    try {
      final script = SentryWebViewScript.build(allowedHosts: allowedHosts);
      final identifier = switch (controller.platform) {
        AndroidWebViewController c => c.webViewIdentifier,
        WebKitWebViewController c => c.webViewIdentifier,
        _ => null,
      };
      if (identifier == null) return false;

      final installed = await _channel.invokeMethod<bool>('setTraceScript', {
        'identifier': identifier,
        'source': script?.source,
        'origins': script?.allowedOriginRules.toList() ?? <String>[],
      });
      if (script == null) return false;
      if (installed == true) return true;
    } catch (_) {
      // Platform exceptions may contain method arguments, including trace data.
    }
    internalLogger.warning(
      'Could not install the WebView document-start script.',
    );
    return false;
  }
}
