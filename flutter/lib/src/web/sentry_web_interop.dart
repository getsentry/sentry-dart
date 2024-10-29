import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'sentry_js_bridge.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native_invoker.dart';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'sentry_script_loader.dart';
import 'sentry_web_binding.dart';

/// API for accessing native Sentry JS SDK methods
@internal
class SentryWebInterop
    with SentryNativeSafeInvoker
    implements SentryWebBinding {
  SentryWebInterop(this._jsBridge, this._options, this._scriptLoader);

  @override
  SentryFlutterOptions get options => _options;
  final SentryFlutterOptions _options;
  final SentryScriptLoader _scriptLoader;
  final SentryJsApi _jsBridge;

  SentryJsReplay? _replay;

  @override
  Future<void> init(SentryFlutterOptions options) async {
    return tryCatchAsync('init', () async {
      await _scriptLoader.loadScripts();

      if (!_scriptLoader.isLoaded) {
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
        'replaysOnErrorSampleRate':
            options.experimental.replay.onErrorSampleRate,
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
