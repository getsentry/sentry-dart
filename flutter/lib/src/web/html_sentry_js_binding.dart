import 'dart:js';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return HtmlSentryJsBinding();
}

class HtmlSentryJsBinding implements SentryJsBinding {
  HtmlSentryJsBinding({JsObject? sentry}) : _sentry = sentry;

  JsObject? _sentry;
  dynamic _client;

  @override
  void init(Map<String, dynamic> options) {
    _sentry ??= context['Sentry'] as JsObject;
    _sentry!.callMethod('init', [JsObject.jsify(options)]);
    _client = _sentry?.callMethod('getClient');
  }

  @override
  void close() {
    if (_sentry != null) {
      _sentry?.callMethod('close');
      _sentry = null;
      context['Sentry'] = null;
    }
  }

  @override
  void captureEnvelope(List<Object> envelope) {
    if (_client != null) {
      _client.callMethod('sendEnvelope', [JsObject.jsify(envelope)]);
    }
  }
}
