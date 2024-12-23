import 'dart:js';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return HtmlSentryJsBinding();
}

class HtmlSentryJsBinding implements SentryJsBinding {
  HtmlSentryJsBinding({JsObject? sentry}) : _sentry = sentry;

  JsObject? _sentry;

  @override
  void init(Map<String, dynamic> options) {
    _sentry ??= context['Sentry'] as JsObject;
    _sentry!.callMethod('init', [JsObject.jsify(options)]);
  }

  @override
  void captureEnvelope(List<dynamic> envelope) {
    // _sentry?
    // _getClient()?.callMethod('sendEnvelope'.toJS, envelope.jsify());
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
  void captureSession() {
    // TODO: implement captureSession
  }

  @override
  getSession() {
    // TODO: implement getSession
    throw UnimplementedError();
  }
}
