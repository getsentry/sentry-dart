import 'dart:html';
import 'dart:js';

void injectMetaTag(Map<String, String> attributes) {
  final MetaElement meta = document.createElement('meta') as MetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.append(meta);
}

dynamic getJsOptions() {
  final sentry = context['Sentry'] as JsObject;
  return sentry.callMethod('getClient').callMethod('getOptions');
}
