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

    simulateCrash();
  }

  void simulateCrash() {
    // First get the current session
    final isolationScope = SentryJsIsolationScope();
    JSObject? currentSession = isolationScope.getSession();

    if (currentSession == null) {
      print('No active session to crash, starting one...');
      startSession();
    }

    currentSession = isolationScope.getSession();

    // Important: Update these fields while preserving others
    currentSession?['status'] = 'crashed'.toJS;
    currentSession?['errors'] = 1.toJS;

    // Set it back and send it
    isolationScope.setSession(currentSession!);

    final session = SentryJsIsolationScope().getSession();
    captureSession();

    // After sending a crashed session, you might want to start a new one
    _startSession({'ignoreDuration': true}.jsify());
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
  void startSession() {
    _startSession({'ignoreDuration': true}.jsify());
  }

  @override
  void captureSession() {
    _captureSession();
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
  external void setSession(JSAny session);
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

/**
 * Sessions
 *
 * Terminal State: When a session is marked as "crashed", it enters a terminal state and according to Sentry's session protocol,
 * "When a session is moved away from ok it must not be updated anymore." This means the session won't receive further updates.
 * Session Continuation: The crashed session remains on the isolation scope until explicitly replaced.
 * New Session Creation: In browser environments, a new session is automatically created on:
 * Page reload (which naturally happens after many crashes) or Navigation to a new route
 */
