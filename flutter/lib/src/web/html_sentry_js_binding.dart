// Will be removed in v9
// ignore: deprecated_member_use
import 'dart:js';

import 'package:flutter/cupertino.dart';

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
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }

    _sentry ??= context['Sentry'] as JsObject;
    _sentry!.callMethod('init', [JsObject.jsify(options)]);
    _client = _sentry!.callMethod('getClient');
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

  @override
  void captureEnvelope(List<Object> envelope) {
    if (_client != null) {
      _client.callMethod('sendEnvelope', [JsObject.jsify(envelope)]);
    }
  }

  @visibleForTesting
  @override
  getJsOptions() {
    // newest flutter version removed dartify from JsObject
    // we will remove this file in v9 anyway
    return null;
  }
}
