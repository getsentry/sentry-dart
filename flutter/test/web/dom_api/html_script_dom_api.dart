import 'dart:html';

import 'script_dom_api.dart';

class HtmlScriptElement implements SentryScriptElement {
  final ScriptElement element;

  HtmlScriptElement(this.element);

  @override
  void remove() {
    element.remove();
  }

  @override
  String get src => element.src;
}

List<SentryScriptElement> querySelectorAll(String query) {
  final scripts = document.querySelectorAll(query);
  return scripts
      .map((script) => HtmlScriptElement(script as ScriptElement))
      .toList();
}
