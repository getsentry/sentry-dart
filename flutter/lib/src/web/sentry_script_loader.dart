import 'dart:async';
import 'dart:html';

import '../../sentry_flutter.dart';

// todo: set up ci to update this and the integrity
const _sdkVersion = '8.37.1';

const productionScripts = [
  {
    'url':
        'https://browser.sentry-cdn.com/$_sdkVersion/bundle.tracing.replay.min.js',
    'integrity':
        'sha384-IZS0kTfvAku3LBcvcHWThKT6lKBimvLUVNZgqF/jtmVAw99L25MM+RhAnozr6iVY'
  },
  {
    'url': 'https://browser.sentry-cdn.com/$_sdkVersion/replay-canvas.min.js',
    'integrity':
        'sha384-UNUCiMVh5gTr9Z45bRUPU5eOHHKGOI80UV3zM858k7yV/c6NNhtSJnIDjh+jJ8Vk'
  },
];
const debugScripts = [
  {
    'url':
        'https://browser.sentry-cdn.com/$_sdkVersion/bundle.tracing.replay.js',
  },
  {
    'url': 'https://browser.sentry-cdn.com/$_sdkVersion/replay-canvas.js',
  },
];

class SentryScriptLoader {
  SentryScriptLoader(this.options, {List<Map<String, String>>? scripts})
      : _scripts = scripts ?? _getScriptConfigs(options.platformChecker);

  final SentryFlutterOptions options;
  final List<Map<String, String>>? _scripts;
  bool get isLoaded => _scriptLoaded;
  bool _scriptLoaded = false;

  Future<void> loadScripts({bool useIntegrity = true}) async {
    if (_scriptLoaded || _scripts == null) return;

    try {
      await Future.wait(_scripts!.map((script) => _loadScript(
          script['url']!, useIntegrity ? script['integrity'] : null)));
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

List<Map<String, String>> _getScriptConfigs(PlatformChecker platformChecker) {
  if (platformChecker.isDebugMode()) {
    return debugScripts;
  } else {
    return productionScripts;
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
