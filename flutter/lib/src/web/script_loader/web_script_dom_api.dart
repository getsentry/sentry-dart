import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

Future<void> loadScript(String src, String? integrity) {
  final completer = Completer<void>();
  final script = HTMLScriptElement()
    ..src = src
    ..crossOrigin = 'anonymous'
    ..onLoad.listen((_) => completer.complete())
    ..onError.listen((event) => completer.completeError('Failed to load $src'));

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
