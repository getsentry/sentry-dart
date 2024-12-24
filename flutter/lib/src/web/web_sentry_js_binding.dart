import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  @override
  void init(Map<String, dynamic> options) {
    _SentryJsBridge.init(options.jsify());
  }

  @override
  void close() {
    final sentryProp = globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      _SentryJsBridge.close();
      globalThis['Sentry'] = null;
    }
  }

  @override
  void captureEnvelope(List<Object> envelope) {
    _SentryJsBridge.getClient().sendEnvelope(envelope.jsify());
  }

  @override
  void captureSession() {
    _SentryJsBridge.captureSession();
  }

  @override
  getSession() {
    return _SentryJsBridge.getSession();
  }
}

@JS('globalThis')
external JSObject get globalThis;

@JS('Sentry')
@staticInterop
class _SentryJsBridge {
  external static void init(JSAny? options);

  external static void close();

  external static SentryJsClient getClient();

  external static void captureSession();

  external static SentryJsScope? getCurrentScope();

  external static SentryJsScope? getIsolationScope();

  static SentryJsSession? getSession() {
    return getCurrentScope()?.getSession() ?? getIsolationScope()?.getSession();
  }
}

@JS('Session')
@staticInterop
class SentryJsSession {}

extension SentryJsSessionExtension on SentryJsSession {
  external JSString status;

  external JSNumber errors;
}

@JS('Scope')
@staticInterop
class SentryJsScope {}

extension SentryScopeExtension on SentryJsScope {
  external SentryJsSession? getSession();
}

@JS('Client')
@staticInterop
class SentryJsClient {}

extension SentryJsClientExtension on SentryJsClient {
  external JSAny? sendEnvelope(JSAny? envelope);
}
