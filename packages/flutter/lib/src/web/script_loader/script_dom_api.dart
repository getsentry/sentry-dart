import 'package:meta/meta.dart';

export 'noop_script_dom_api.dart'
    if (dart.library.js_interop) 'web_script_dom_api.dart';

@internal
abstract class SentryScriptElement {
  String get src;
  String? get integrity;
  void remove();
}
