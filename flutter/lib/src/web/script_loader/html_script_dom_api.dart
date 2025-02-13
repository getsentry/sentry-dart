import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html';
// ignore: deprecated_member_use
import 'dart:js_util' as js_util;

import '../../../sentry_flutter.dart';
import 'script_dom_api.dart';
import 'sentry_script_loader.dart';

Future<void> loadScript(String src, SentryOptions options,
    {String? integrity,
    String trustedTypePolicyName = defaultTrustedPolicyName}) {
  final completer = Completer<void>();

  final script = ScriptElement()
    ..crossOrigin = 'anonymous'
    ..onLoad.listen((_) => completer.complete())
    ..onError.listen((event) => completer.completeError('Failed to load $src'));

  TrustedScriptUrl? trustedUrl;

  // If TrustedTypes are available, prepare a trusted URL
  final trustedTypes = js_util.getProperty<dynamic>(window, 'trustedTypes');
  if (trustedTypes != null) {
    try {
      final policy =
          js_util.callMethod<dynamic>(trustedTypes as Object, 'createPolicy', [
        trustedTypePolicyName,
        js_util.jsify({
          'createScriptURL': (String url) => src,
        })
      ]);
      trustedUrl =
          js_util.callMethod(policy as Object, 'createScriptURL', [src]);
    } catch (e) {
      // will be caught by loadWebSdk
      throw TrustedTypesException();
    }
  }

  if (trustedUrl != null) {
    js_util.setProperty(script, 'src', trustedUrl);
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
  final ScriptElement element;

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
  return scripts
      .map((script) => _ScriptElement(script as ScriptElement))
      .toList();
}
