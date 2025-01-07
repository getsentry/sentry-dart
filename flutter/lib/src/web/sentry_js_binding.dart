export 'noop_sentry_js_binding.dart'
    if (dart.html) 'html_sentry_js_binding.dart'
    if (dart.library.js_interop) 'web_sentry_js_binding.dart';

abstract class SentryJsBinding {
  void init(Map<String, dynamic> options);
  void close();
  void captureEnvelope(List<Object> envelope);
}
