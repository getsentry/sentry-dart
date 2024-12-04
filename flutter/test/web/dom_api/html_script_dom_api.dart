import 'dart:html';

import 'script_dom_api.dart';

class HtmlScriptElement implements TestScriptElement {
  final ScriptElement element;

  HtmlScriptElement(this.element);

  @override
  void remove() {
    element.remove();
  }

  @override
  String get src => element.src;
}

List<TestScriptElement> fetchAllScripts() {
  final scripts = document.querySelectorAll('script');
  return scripts
      .map((script) => HtmlScriptElement(script as ScriptElement))
      .toList();
}

void injectMetaTag(Map<String, String> attributes) {
  final MetaElement meta = document.createElement('meta') as MetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.append(meta);
}
