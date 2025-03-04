import 'package:flutter/cupertino.dart';

export 'noop_sentry_js_binding.dart'
    if (dart.library.js_interop) 'web_sentry_js_binding.dart';

abstract class SentryJsBinding {
  void init(Map<String, dynamic> options);
  void close();
  void captureEnvelope(List<Object> envelope);

  @visibleForTesting
  dynamic getJsOptions();
}

/// Names of the JS integrations that we want to add when initializing the JS SDK
class SentryJsIntegrationName {
  const SentryJsIntegrationName._();

  static const String globalHandlers = 'globalHandlersIntegration';
  static const String dedupe = 'dedupeIntegration';
}
