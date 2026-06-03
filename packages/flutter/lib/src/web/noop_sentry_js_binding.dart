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
  void setUser(Map<String, dynamic>? user) {}

  @override
  void addBreadcrumb(Map<String, dynamic> breadcrumb) {}

  @override
  void addReplayBreadcrumb(Map<String, dynamic> breadcrumb) {}

  @override
  void clearBreadcrumbs() {}

  @override
  void setContext(String key, Object? value) {}

  @override
  void removeContext(String key) {}

  @override
  void setExtra(String key, Object? value) {}

  @override
  void removeExtra(String key) {}

  @override
  void setTag(String key, String value) {}

  @override
  void removeTag(String key) {}

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

  @override
  String? getReplayId({bool onlyIfSampled = false}) {
    return null;
  }
}
