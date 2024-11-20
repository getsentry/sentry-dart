import 'dart:js_interop';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

import 'script_dom_api.dart';

class _ScriptElement implements SentryScriptElement {
  final HTMLScriptElement element;

  _ScriptElement(this.element);

  @override
  void remove() {
    element.remove();
  }

  @override
  String get src => element.src;
}

List<SentryScriptElement> querySelectorAll(String query) {
  final scripts = document.querySelectorAll(query);
  // ignore: sdk_version_since
  final jsArray = JSArray.from(scripts);
  return jsArray.toDart
      .map((script) => _ScriptElement(script as HTMLScriptElement))
      .toList();
}
