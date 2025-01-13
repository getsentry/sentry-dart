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
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }

    _sentry ??= context['Sentry'] as JsObject;
    _sentry!.callMethod('init', [JsObject.jsify(options)]);
  }

  JsObject? _createIntegration(String integration) {
    switch (integration) {
      case SentryJsIntegrationName.globalHandlers:
      case SentryJsIntegrationName.dedupe:
        final jsIntegration = _sentry?.callMethod(integration, []);
        return jsIntegration is JsObject ? jsIntegration : null;
      default:
        return null;
    }
  }

  @override
  void close() {
    if (_sentry != null) {
      _sentry?.callMethod('close');
      _sentry = null;
      context['Sentry'] = null;
    }
  }
}
