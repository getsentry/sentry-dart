import 'package:flutter/cupertino.dart';

export 'noop_sentry_js_binding.dart'
    if (dart.library.js_interop) 'web_sentry_js_binding.dart';

abstract class SentryJsBinding {
  void init(Map<String, dynamic> options);
  void close();
  void captureEnvelope(List<Object> envelope);
  void setUser(Map<String, dynamic>? user);
  void addBreadcrumb(Map<String, dynamic> breadcrumb);
  void addReplayBreadcrumb(Map<String, dynamic> breadcrumb);
  void clearBreadcrumbs();
  void setContext(String key, Object? value);
  void removeContext(String key);
  void setExtra(String key, Object? value);
  void removeExtra(String key);
  void setTag(String key, String value);
  void removeTag(String key);
  void startSession();
  Map<dynamic, dynamic>? getSession();
  void updateSession({int? errors, String? status});
  void captureSession();
  Map<String, String>? getFilenameToDebugIdMap();
  String? getReplayId({bool onlyIfSampled = false});
  @visibleForTesting
  dynamic getJsOptions();
}

/// Names of the JS integrations that we want to add when initializing the JS SDK
class SentryJsIntegrationName {
  const SentryJsIntegrationName._();

  static const String globalHandlers = 'globalHandlersIntegration';
  static const String dedupe = 'dedupeIntegration';
  static const String replay = 'replayIntegration';
  static const String replayCanvas = 'replayCanvasIntegration';
}
