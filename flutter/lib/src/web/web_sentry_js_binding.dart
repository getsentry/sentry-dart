import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:meta/meta.dart';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  @override
  void init(Map<String, dynamic> options) {
    SentryJsBridge.init(options.jsify());
  }

  @override
  void close() {
    final sentryProp = globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      SentryJsBridge.close();
      globalThis['Sentry'] = null;
    }
  }

  @override
  void captureEnvelope(List<Object> envelope) {
    SentryJsBridge.getClient().sendEnvelope(envelope.jsify());
  }

  @override
  void captureSession() {
    SentryJsBridge.captureSession();
  }

  @override
  getSession() {
    return SentryJsBridge.getSession();
  }
}

@JS('globalThis')
@internal
external JSObject get globalThis;

@JS('Sentry')
@staticInterop
@internal
class SentryJsBridge {
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
@internal
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
@internal
class SentryJsClient {}

extension SentryJsClientExtension on SentryJsClient {
  external JSAny? sendEnvelope(JSAny? envelope);

  external JSFunction on(JSString hook, JSFunction callback);
}
