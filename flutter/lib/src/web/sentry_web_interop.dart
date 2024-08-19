import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native_invoker.dart';
import 'sentry_js_bridge.dart';
import 'dart:html';

import 'sentry_web_binding.dart';

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryWebInterop
    with SentryNativeSafeInvoker
    implements SentryWebBinding {
  @override
  SentryFlutterOptions get options => _options;
  final SentryFlutterOptions _options;

  SentryWebInterop(this._options);

  @override
  Future<void> init(SentryFlutterOptions options) async {
    return tryCatchAsync('init', () async {
      await _loadSentryScripts(options);

      if (!_scriptLoaded) {
        options.logger(SentryLevel.warning,
            'Sentry scripts are not loaded, cannot initialize Sentry JS SDK.');
      }

      final Map<String, dynamic> config = {
        'dsn': options.dsn,
        'debug': options.debug,
        'environment': options.environment,
        'release': options.release,
        'dist': options.dist,
        'autoSessionTracking': options.enableAutoSessionTracking,
        'attachStacktrace': options.attachStacktrace,
        'maxBreadcrumbs': options.maxBreadcrumbs,
        'replaysSessionSampleRate':
            options.experimental.replay.sessionSampleRate,
        'replaysOnErrorSampleRate': options.experimental.replay.errorSampleRate,
        // using defaultIntegrations ensures the we can control which integrations are added
        'defaultIntegrations': [
          SentryJsBridge.replayIntegration({
            'maskAllText': options.experimental.replay.redactAllText,
            // todo: is redactAllImages the same as blockAllMedia?
            'blockAllMedia': options.experimental.replay.redactAllImages,
          }.jsify()),
          SentryJsBridge.replayCanvasIntegration(),
        ],
      };

      // Remove null values to avoid unnecessary properties in the JS object
      config.removeWhere((key, value) => value == null);

      SentryJsBridge.init(config.jsify());

      SpotlightBridge.init();
    });
  }

  @override
  Future<void> captureEvent(SentryEvent event) async {
    tryCatchSync('captureEvent', () {
      SentryJsBridge.captureEvent(event.toJson().jsify());
    });
  }

  @override
  Future<void> captureEnvelope(SentryEnvelope envelope) async {
    tryCatchSync('captureEnvelope', () {
      SentryJsBridge.getClient().sendEnvelope([
        envelope.header.toJson(),
        [
          envelope.items.map((item) {
            return [
              item.header.toJson(),
              item.originalObject,
            ];
          }).toList(),
        ]
      ].jsify());
    });
  }

  @override
  Future<void> close() async {
    tryCatchSync('close', () {
      SentryJsBridge.close();
    });
  }
}

bool _scriptLoaded = false;

Future<void> _loadSentryScripts(SentryFlutterOptions options,
    {bool useIntegrity = true}) async {
  if (_scriptLoaded) return;

  final scripts = [
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
    {
      // todo: fix double events from spotlight
      'url':
          'https://unpkg.com/@spotlightjs/overlay@latest/dist/sentry-spotlight.iife.js',
    },
  ];

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
