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
  void captureEnvelope(List<Object> envelope) {}

  @override
  getJsOptions() {}

  @override
  void captureSession() {}

  @override
  void startSession() {}

  @override
  Map<dynamic, dynamic>? getSession() {
    return null;
  }

  @override
  void updateSession({int? errors, String? status}) {}

  @override
  Map<String, String>? getFilenameToDebugIdMap() {
    return {};
  }
}
