# Sentry for webview_flutter

Flutter plugin for connecting Sentry traces to pages displayed by
`webview_flutter` on Android, iOS, and macOS. This package currently provides
native plugin registration. The manual tracing API is tracked in
[#4220](https://github.com/getsentry/sentry-dart/issues/4220).

The plugin requires Flutter 3.44 or later. On Apple platforms, enable Swift
Package Manager for `sentry_flutter`. The platform dependency floors provide
the Android plugin-binding lookup (4.13.0) and the iOS registrar and macOS
registry lookups (3.26.0) for accessing a controller’s native WebView.
