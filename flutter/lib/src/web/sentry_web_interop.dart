import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'sentry_js_bridge.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native_invoker.dart';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'sentry_web_binding.dart';

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryWebInterop
    with SentryNativeSafeInvoker
    implements SentryWebBinding {
  SentryWebInterop(this._jsBridge, this._options);

  @override
  SentryFlutterOptions get options => _options;
  final SentryFlutterOptions _options;
  final SentryJsApi _jsBridge;

  SentryJsReplay? _replay;

  @override
  Future<void> init(SentryFlutterOptions options) async {
    return tryCatchAsync('init', () async {
      await _loadSentryScripts(options);

      if (!_scriptLoaded) {
        options.logger(SentryLevel.warning,
            'Sentry scripts are not loaded, cannot initialize Sentry JS SDK.');
      }

      _replay = _jsBridge.replayIntegration({
        'maskAllText': options.experimental.replay.redactAllText,
        'blockAllMedia': options.experimental.replay.redactAllImages,
      }.jsify());

      final Map<String, dynamic> config = {
        'dsn': options.dsn,
        'debug': options.debug,
        'environment': options.environment,
        'release': options.release,
        'dist': options.dist,
        'sampleRate': options.sampleRate,
        // 'tracesSampleRate': 1.0, needed if we want to enable some auto performance tracing of JS SDK
        'autoSessionTracking': options.enableAutoSessionTracking,
        'attachStacktrace': options.attachStacktrace,
        'maxBreadcrumbs': options.maxBreadcrumbs,
        'replaysSessionSampleRate':
            options.experimental.replay.sessionSampleRate,
        'replaysOnErrorSampleRate': options.experimental.replay.errorSampleRate,
        // using defaultIntegrations ensures that we can control which integrations are added
        'defaultIntegrations': [
          _replay,
          _jsBridge.replayCanvasIntegration(),
          // todo: check which browser integrations make sense
          // todo: we have to figure out out how to hook the integration event processing
          // from JS to the Flutter layer
          // _jsBridge.breadcrumbsIntegration()
          // not sure if web vitals are correct, needs more testing
          // _jsBridge.browserTracingIntegration()
        ],
      };

      // Remove null values to avoid unnecessary properties in the JS object
      config.removeWhere((key, value) => value == null);

      _jsBridge.init(config.jsify());
    });
  }

  @override
  Future<void> captureEnvelope(SentryEnvelope envelope) async {
    return tryCatchAsync('captureEnvelope', () async {
      final List<dynamic> envelopeItems = [];

      for (final item in envelope.items) {
        final originalObject = item.originalObject;
        envelopeItems.add([
          (await item.header.toJson()),
          (await originalObject?.getPayload())
        ]);

        // We use `sendEnvelope` where sessions are not managed in the JS SDK
        // so we have to do it manually
        if (originalObject is SentryEvent &&
            originalObject.exceptions?.isEmpty == false) {
          final session = _jsBridge.getSession();
          if (envelope.containsUnhandledException) {
            session?.status = 'crashed'.toJS;
          }
          session?.errors = originalObject.exceptions?.length.toJS ?? 0.toJS;
          _jsBridge.captureSession();
        }
      }

      final jsEnvelope = [envelope.header.toJson(), envelopeItems].jsify();

      _jsBridge.getClient().sendEnvelope(jsEnvelope);
    });
  }

  @override
  Future<void> close() async {
    return tryCatchSync('close', () {
      _jsBridge.close();
    });
  }

  @override
  Future<void> flushReplay() async {
    return tryCatchAsync('flushReplay', () async {
      if (_replay == null) {
        return;
      }
      await js_util.promiseToFuture<void>(_replay!.flush());
    });
  }

  @override
  Future<SentryId?> getReplayId() async {
    return tryCatchAsync('getReplayId', () async {
      final id = await _replay?.getReplayId()?.toDart;
      return id == null ? null : SentryId.fromId(id);
    });
  }
}

bool _scriptLoaded = false;
Future<void> _loadSentryScripts(SentryFlutterOptions options,
    {bool useIntegrity = true}) async {
  if (_scriptLoaded) return;

  // todo: put this somewhere else so we can auto-update it through CI
  List<Map<String, String>> scripts = [
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

  if (options.debug) {
    options.logger(SentryLevel.debug,
        'Option `debug` is enabled, loading non-minified Sentry scripts.');
    scripts = [
      {
        'url': 'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.js',
      },
      {
        'url': 'https://browser.sentry-cdn.com/8.24.0/replay-canvas.js',
      },
    ];
  }

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
