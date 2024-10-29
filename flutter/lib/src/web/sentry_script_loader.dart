import 'dart:async';
import 'dart:html';

import '../../sentry_flutter.dart';

class SentryScriptLoader {
  final SentryFlutterOptions options;

  SentryScriptLoader(this.options);

  bool get isLoaded => _scriptLoaded;
  bool _scriptLoaded = false;

  Future<void> loadScripts({bool useIntegrity = true}) async {
    if (_scriptLoaded) return;

    final scripts = _getScriptConfigs(options.platformChecker);

    try {
      await Future.wait(scripts.map((script) => _loadScript(
          script['url']!, useIntegrity ? script['integrity'] : null)));
      _scriptLoaded = true;
      options.logger(
          SentryLevel.debug, 'All Sentry scripts loaded successfully.');
    } catch (e) {
      options.logger(SentryLevel.error,
          'Failed to load Sentry scripts, cannot initialize Sentry JS SDK.');
    }
  }

  List<Map<String, String>> _getScriptConfigs(PlatformChecker platformChecker) {
    if (platformChecker.isDebugMode()) {
      return _debugScripts;
    } else {
      return _productionScripts;
    }
  }

  static const _productionScripts = [
    {
      'url':
          'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.min.js',
      'integrity':
          'sha384-eEn/WSvcP5C2h5g0AGe5LCsheNNlNkn/iV8y5zOylmPoOfSyvZ23HBDnOhoB0sdL'
    },
    {
      'url': 'https://browser.sentry-cdn.com/8.24.0/replay-canvas.min.js',
      'integrity':
          'sha384-gSFCG8IdZobb6PWs7SwuaES/R5PPt+gw4y6N/Kkwlic+1Hzf21EUm5Dg/WbYMxTE'
    },
  ];
  static const _debugScripts = [
    {
      'url': 'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.js',
    },
    {
      'url': 'https://browser.sentry-cdn.com/8.24.0/replay-canvas.js',
    },
  ];
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
