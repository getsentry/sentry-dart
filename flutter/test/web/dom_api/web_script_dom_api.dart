// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

import 'script_dom_api.dart';

class _ScriptElement implements TestScriptElement {
  final HTMLScriptElement element;

  _ScriptElement(this.element);

  @override
  void remove() {
    element.remove();
  }

  @override
  String get src => element.src;
}

List<TestScriptElement> fetchAllScripts() {
  final scripts = document.querySelectorAll('script');

  List<TestScriptElement> elements = [];
  for (int i = 0; i < scripts.length; i++) {
    final node = scripts.item(i);
    elements.add(_ScriptElement(node as HTMLScriptElement));
  }

  return elements;
}

void injectMetaTag(Map<String, String> attributes) {
  final HTMLMetaElement meta =
      document.createElement('meta') as HTMLMetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.appendChild(meta);
}
