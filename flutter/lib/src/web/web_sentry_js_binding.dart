import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:meta/meta.dart';

import 'debug_ids.dart';
import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  SentryJsClient? _client;
  JSObject? _options;

  @override
  void init(Map<String, dynamic> options) {
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }
    _init(options.jsify());
    _client = SentryJsClient();
    _options = _client?.getOptions();
  }

  @override
  void updateSession({int? errors, String? status}) {
    final isolationScope = SentryJsIsolationScope();
    JSObject? currentSession = isolationScope.getSession();
    if (currentSession == null) {
      return;
    }

    if (status != null) {
      currentSession['status'] = status.toJS;
    }

    if (errors != null) {
      currentSession['errors'] = errors.toJS;
    }

    isolationScope.setSession(currentSession);
  }

  JSObject? _createIntegration(String integration) {
    switch (integration) {
      case SentryJsIntegrationName.globalHandlers:
        return _globalHandlersIntegration();
      case SentryJsIntegrationName.dedupe:
        return _dedupeIntegration();
      default:
        return null;
    }
  }

  @override
  void close() {
    final sentryProp = globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      _close();
      globalThis['Sentry'] = null;
    }
  }

  @override
  void captureEnvelope(List<Object> envelope) {
    if (_client != null) {
      _client?.sendEnvelope(envelope.jsify());
    }
  }

  @visibleForTesting
  @override
  getJsOptions() {
    return _client?.getOptions().dartify();
  }

  @override
  void startSession({bool ignoreDuration = false}) {
    _startSession({'ignoreDuration': ignoreDuration}.jsify());
  }

  @override
  void captureSession() {
    _captureSession();
  }

  @override
  Map<dynamic, dynamic>? getSession() {
    try {
      return SentryJsIsolationScope().getSession().dartify()
          as Map<dynamic, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, String>? getFilenameToDebugIdMap() {
    final options = _options;
    if (options == null) {
      return null;
    }

    return getOrCreateFilenameToDebugIdMap(options);
  }
}

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.close')
external void _close();

@JS('Sentry.getIsolationScope')
@staticInterop
class SentryJsIsolationScope {
  external factory SentryJsIsolationScope();
}

extension _SentryJsIsolationScopeExtension on SentryJsIsolationScope {
  external JSObject? getSession();
  external void setSession(JSObject session);
}

@JS('Sentry.getClient')
@staticInterop
class SentryJsClient {
  external factory SentryJsClient();
}

extension _SentryJsClientExtension on SentryJsClient {
  external void sendEnvelope(JSAny? envelope);
  external JSObject? getOptions();
}

@JS('Sentry.startSession')
external void _startSession(JSAny? context);

@JS('Sentry.captureSession')
external void _captureSession();

@JS('Sentry.globalHandlersIntegration')
external JSObject _globalHandlersIntegration();

@JS('Sentry.dedupeIntegration')
external JSObject _dedupeIntegration();

@JS('globalThis')
@internal
external JSObject get globalThis;
