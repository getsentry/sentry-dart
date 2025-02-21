import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart';
import '../../../sentry_flutter.dart';
import 'script_dom_api.dart';
import 'sentry_script_loader.dart';

Future<void> loadScript(String src, SentryOptions options,
    {String? integrity,
    String trustedTypePolicyName = defaultTrustedPolicyName}) {
  final completer = Completer<void>();
  final script = HTMLScriptElement()
    ..crossOrigin = 'anonymous'
    ..onLoad.listen((_) => completer.complete())
    ..onError.listen((event) => completer.completeError('Failed to load $src'));

  TrustedScriptURL? trustedUrl;
  if (!window.trustedTypes.isUndefinedOrNull) {
    try {
      final TrustedTypePolicy policy = window.trustedTypes.createPolicy(
          trustedTypePolicyName,
          TrustedTypePolicyOptions(
            createScriptURL: ((JSString url) => src).toJS,
          ));
      trustedUrl = policy.createScriptURL(src, null);
    } catch (e) {
      // will be caught by loadWebSdk
      throw TrustedTypesException();
    }
  }

  if (trustedUrl != null) {
    (script as JSObject).setProperty('src'.toJS, trustedUrl);
  } else {
    script.src = src;
  }

  if (integrity != null) {
    script.integrity = integrity;
  }

  // JS SDK needs to be loaded before everything else
  final head = document.head;
  if (head != null) {
    if (head.hasChildNodes()) {
      head.insertBefore(script, head.firstChild);
    } else {
      head.append(script);
    }
  }
  return completer.future;
}

class _ScriptElement implements SentryScriptElement {
  final HTMLScriptElement element;

  _ScriptElement(this.element);

  @override
  void remove() {
    element.remove();
  }

  @override
  String get src => element.src;

  @override
  String? get integrity => element.integrity;
}

List<SentryScriptElement> fetchScripts(String query) {
  final scripts = document.querySelectorAll(query);

  List<SentryScriptElement> elements = [];
  for (int i = 0; i < scripts.length; i++) {
    final node = scripts.item(i);
    elements.add(_ScriptElement(node as HTMLScriptElement));
  }

  return elements;
}
