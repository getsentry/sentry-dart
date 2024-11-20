export 'noop_script_dom_api.dart'
    if (dart.library.html) 'html_script_dom_api.dart'
    if (dart.library.js_interop) 'web_script_dom_api.dart';

abstract class SentryScriptElement {
  String get src;
  void remove();
}
