import 'dart:async';
import 'dart:html';

Future<void> loadScript(String src, String? integrity) {
  final completer = Completer<void>();
  final script = ScriptElement()
    ..src = src
    ..crossOrigin = 'anonymous'
    ..onLoad.listen((_) => completer.complete())
    ..onError.listen((event) => completer.completeError('Failed to load $src'));

  if (integrity != null) {
    script.integrity = integrity;
  }

  document.head?.append(script);
  return completer.future;
}