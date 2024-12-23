import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return NoOpSentryJsBinding();
}

class NoOpSentryJsBinding implements SentryJsBinding {
  NoOpSentryJsBinding();

  @override
  void init(Map<String, dynamic> options) {}

  @override
  void close() {}

  @override
  void captureSession() {}

  @override
  getSession() {}

  @override
  void captureEnvelope(List<Object> envelope) {}
}
