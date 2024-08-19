import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/src/protocol/sentry_event.dart';
import 'package:sentry/src/sentry_envelope.dart';
import '../../sentry_flutter.dart';
import 'sentry_js_bridge.dart';
import 'dart:html';

import '../sentry_flutter_options.dart';
import 'sentry_web_binding.dart';
import 'package:js/js_util.dart' as js_util;

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryWebInterop implements SentryWebBinding {
  final SentryFlutterOptions _options;

  SentryWebInterop(this._options);

  @override
  Future<void> init(SentryFlutterOptions options) async {
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
      'replaysSessionSampleRate': options.experimental.replay.sessionSampleRate,
      'replaysOnErrorSampleRate': options.experimental.replay.errorSampleRate,
      'defaultIntegrations': [
        SentryJsBridge.replayIntegration(js_util.jsify({
          'maskAllText': options.experimental.replay.redactAllText,
          // todo: is redactAllImages the same?
          'blockAllMedia': options.experimental.replay.redactAllImages,
        })),
        SentryJsBridge.replayCanvasIntegration(),
      ],
    };

    // Remove null values to avoid unnecessary properties in the JS object
    config.removeWhere((key, value) => value == null);

    SentryJsBridge.init(js_util.jsify(config));

    return Future.value();
  }

  @override
  Future<void> captureEvent(SentryEvent event) {
    SentryJsBridge.captureEvent(js_util.jsify(event.toJson()));

    return Future.value();
  }

  @override
  Future<void> captureEnvelope(SentryEnvelope envelope) async {
    SentryJsBridge.getClient().sendEnvelope(js_util.jsify([
      envelope.header.toJson(),
      [
        envelope.items.map((item) {
          return [
            item.header.toJson(),
            item.originalObject,
          ];
        }).toList(),
      ]
    ]));

    return Future.value();
  }

  @override
  Future<void> close() {
    SentryJsBridge.close();

    return Future.value();
  }
}

bool _scriptLoaded = false;

Future<void> _loadSentryScripts(SentryFlutterOptions options) async {
  if (_scriptLoaded) return;

  List<String> scriptUrls = [
    'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.min.js',
    'https://browser.sentry-cdn.com/8.24.0/replay-canvas.min.js'
  ];

  Map<String, String> integrityHashes = {
    'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.min.js':
        'sha384-eEn/WSvcP5C2h5g0AGe5LCsheNNlNkn/iV8y5zOylmPoOfSyvZ23HBDnOhoB0sdL',
    'https://browser.sentry-cdn.com/8.24.0/replay-canvas.min.js':
        'sha384-gSFCG8IdZobb6PWs7SwuaES/R5PPt+gw4y6N/Kkwlic+1Hzf21EUm5Dg/WbYMxTE'
  };

  List<Future<void>> loadFutures = [];

  for (String url in scriptUrls) {
    loadFutures.add(_loadScript(url, integrityHashes[url]!));
  }

  try {
    await Future.wait(loadFutures);
    _scriptLoaded = true;
    print('All Sentry scripts loaded successfully');
  } catch (e) {
    options.logger(SentryLevel.error,
        'Failed to load Sentry scripts, cannot initialize Sentry JS SDK.');
  }
}

Future<void> _loadScript(String src, String integrity) {
  Completer<void> completer = Completer<void>();
  ScriptElement script = ScriptElement()
    ..src = src
    ..integrity = integrity
    ..crossOrigin = 'anonymous'
    ..onLoad.listen((_) => completer.complete())
    ..onError.listen((event) => completer.completeError('Failed to load $src'));

  document.head?.append(script);
  return completer.future;
}
