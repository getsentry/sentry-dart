# Sentry for webview_flutter

Connect a Flutter trace to the browser SDK in a WebView on Android, iOS, or
macOS. Initialize `sentry_flutter` in the app and enable browser tracing on the
page. The plugin requires Flutter 3.44 or later and Swift Package Manager on
Apple platforms.

```dart
final controller = WebViewController();
await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
final installed = await SentryWebViewTracing.addTracePropagation(
  controller,
  allowedHosts: ['checkout.example.com'],
);
await controller.loadRequest(Uri.https('checkout.example.com', '/'));
```

Await the call before navigating. Only list hosts whose scripts you trust.
The script runs at document start on top-level HTTPS pages matching a host or
its subdomains. An explicit port restricts the match to that port. Call again
to replace the captured trace and the allowed hosts for future navigations on
the same controller. An empty list clears propagation. The method returns
`false` if it cannot install a script, including on Android WebView versions
without document-start support.

On iOS and macOS, removing a JavaScript channel or enabling zoom can reset the
WebView's user scripts. Make those changes before installing propagation, or
call `addTracePropagation` again afterwards.
