import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/cupertino.dart';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  SentryJsClient? _client;

  @override
  void init(Map<String, dynamic> options) async {
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }
    _init(options.jsify());
    _client = SentryJsClient();
  }

  @override
  void updateSession({required int errors, required String status}) {
    final isolationScope = SentryJsIsolationScope();
    JSObject? currentSession = isolationScope.getSession();
    if (currentSession == null) {
      return;
    }

    currentSession['status'] = status.toJS;
    currentSession['errors'] = errors.toJS;

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
    final sentryProp = _globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      _close();
      _globalThis['Sentry'] = null;
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
external JSObject get _globalThis;
