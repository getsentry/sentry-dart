export 'html_sentry_js_binding.dart'
    if (dart.library.js_interop) 'web_sentry_js_binding.dart';

abstract class SentryJsBinding {
  void init(Map<String, dynamic> options);
}
