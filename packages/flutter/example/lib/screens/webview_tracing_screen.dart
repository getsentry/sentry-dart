// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// Reuse the browser bundle and integrity hash pinned by the Flutter SDK.
// ignore: implementation_imports
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_webview_flutter/sentry_webview_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_config.dart';

const webViewExampleHost = 'webview.example.invalid';
final webViewExampleBrowserBundle = productionScripts.single;

/// Example page served from memory with a trusted HTTPS base URL.
String webViewExampleHtml(String dsn) {
  final bundle = webViewExampleBrowserBundle;
  final encodedDsn = jsonEncode(dsn).replaceAll('<', r'\u003c');
  return '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Flutter WebView trace</title>
<script src="${bundle['url']}" integrity="${bundle['integrity']}" crossorigin="anonymous"></script>
</head><body><h1>Browser pageload</h1><p id="result">Loading the browser SDK…</p>
<script>
if (window.Sentry) {
  Sentry.init({
    dsn: $encodedDsn,
    environment: 'webview-example',
    integrations: [Sentry.browserTracingIntegration()],
    tracesSampleRate: 1
  });
  const span = Sentry.getActiveSpan();
  if (span) {
    const context = span.spanContext();
    window.pageTrace = {traceId: context.traceId, sampled: !!(context.traceFlags & 1)};
    document.getElementById('result').textContent =
      'Trace ' + context.traceId + ' · ' + (window.pageTrace.sampled ? 'sampled' : 'unsampled');
  }
} else {
  document.getElementById('result').textContent = 'Could not load the browser SDK.';
}
</script></body></html>
''';
}

class WebViewTracingScreen extends StatefulWidget {
  const WebViewTracingScreen({super.key});

  @override
  State<WebViewTracingScreen> createState() => _WebViewTracingScreenState();
}

class _WebViewTracingScreenState extends State<WebViewTracingScreen> {
  final _controller = WebViewController();
  late final Future<void> _load = Sentry.startSpan('Open traced WebView', (
    _,
  ) async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    final installed = await SentryWebViewTracing.addTracePropagation(
      _controller,
      allowedHosts: [webViewExampleHost],
    );
    if (!installed) throw StateError('Document-start tracing is unavailable.');
    await _controller.loadHtmlString(
      webViewExampleHtml(exampleDsn),
      baseUrl: 'https://$webViewExampleHost/',
    );
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WebView tracing')),
    body: FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        return WebViewWidget(controller: _controller);
      },
    ),
  );
}
