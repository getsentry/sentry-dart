import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

import '../../../sentry_flutter.dart';
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
