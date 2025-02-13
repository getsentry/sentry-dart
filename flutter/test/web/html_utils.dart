// ignore: deprecated_member_use
import 'dart:html';

void injectMetaTag(Map<String, String> attributes) {
  final MetaElement meta = document.createElement('meta') as MetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.append(meta);
}
