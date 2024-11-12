import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
class SentryScriptLoader {
  SentryScriptLoader(this.options, this.scripts);

  final SentryFlutterOptions options;
  final List<Map<String, String>> scripts;
  bool get isLoaded => _scriptLoaded;
  bool _scriptLoaded = false;

  Future<void> load() async {
    if (_scriptLoaded) return;

    try {
      await Future.wait(scripts.map((script) async {
        final url = script['url'];
        final integrity = script['integrity'];

        if (url != null) {
          return _loadScript(url, integrity);
        }
      }));
      _scriptLoaded = true;
      options.logger(SentryLevel.debug,
          'JS SDK integration: all Sentry scripts loaded successfully.');
    } catch (e, stackTrace) {
      options.logger(
          SentryLevel.error, 'Failed to load Sentry scripts: $e\n$stackTrace');
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }
}

Future<void> _loadScript(String src, String? integrity) {
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
