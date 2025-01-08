import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  SentryJsClient? _client;

  @override
  void init(Map<String, dynamic> options) {
    _init(options.jsify());
    _client = SentryJsClient();
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
}

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.close')
external void _close();

@JS('Sentry.getClient')
@staticInterop
class SentryJsClient {
  external factory SentryJsClient();
}

extension _SentryJsClientExtension on SentryJsClient {
  external void sendEnvelope(JSAny? envelope);
}

@JS('globalThis')
external JSObject get _globalThis;
