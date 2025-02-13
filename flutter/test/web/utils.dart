import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:sentry_flutter/src/web/script_loader/script_dom_api.dart';
import 'package:web/web.dart';

void injectMetaTag(Map<String, String> attributes) {
  final HTMLMetaElement meta =
      document.createElement('meta') as HTMLMetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.appendChild(meta);
}

@JS('Sentry')
external JSObject? get sentry;

dynamic getJsOptions() {
  final client = sentry?.callMethod('getClient'.toJS, null) as JSObject?;
  if (client == null) {
    return null;
  }
  final options = client.callMethod('getOptions'.toJS, null);
  return options?.dartify();
}

List<SentryScriptElement> fetchAllScripts() {
  return fetchScripts('script');
}
