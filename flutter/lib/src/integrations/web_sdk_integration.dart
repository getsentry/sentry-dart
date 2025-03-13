import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../web/script_loader/sentry_script_loader.dart';
import '../web/sentry_js_bundle.dart';

Integration<SentryFlutterOptions> createSdkIntegration(
    SentryNativeBinding native) {
  final scriptLoader = SentryScriptLoader();
  return WebSdkIntegration(native, scriptLoader);
}

class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  WebSdkIntegration(this._web, this._scriptLoader);

  final SentryNativeBinding _web;
  final SentryScriptLoader _scriptLoader;
  SentryFlutterOptions? _options;

  @internal
  static const name = 'webSdkIntegration';

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.autoInitializeNativeSdk) {
      return;
    }

    _options = options;
    _options?.addBeforeSendEventCallback((event, hint) {
      _updateSessionFromEvent(event);
    });

    try {
      final scripts = options.runtimeChecker.isDebugMode()
          ? debugScripts
          : productionScripts;
      await _scriptLoader.loadWebSdk(scripts);
      await _web.init(hub);
      options.sdk.addIntegration(name);
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        '$name failed to be installed.',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  // Currently updating sessions is only relevant for web
  // iOS & Android sessions are handled by the native SDKs directly
  void _updateSessionFromEvent(SentryEvent event) async {
    if (_options?.enableAutoSessionTracking == false) {
      _options?.logger(
        SentryLevel.info,
        'Auto session tracking is disabled. ',
      );
      return;
    }

    bool crashed = event.level == SentryLevel.fatal;
    bool errored = false;

    if (event.exceptions?.isNotEmpty == true) {
      errored = true;

      for (final exception in event.exceptions!) {
        if (exception.mechanism?.handled == false) {
          crashed = true;
          break;
        }
      }
    }

    // A session is updated and that session update is sent in only one of the two following scenarios:
    // 1. Session with non terminal status and 0 errors + an error occurred -> Will set error count to 1 and send update
    // 2. Session with non terminal status and 1 error + a crash occurred -> Will set status crashed and send update
    final session = await _web.getSession();
    if (session == null) {
      return;
    }

    final sessionNonTerminal = session['status'] == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && session['errors'] == 0) ||
            (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final status = crashed ? 'crashed' : session['status'].toString();
      await _web.updateSession(
          status: status, errors: errored || crashed ? 1 : 0);
      await _web.captureSession();
    }
  }

  @override
  FutureOr<void> close() async {
    try {
      await _web.close();
      await _scriptLoader.close();
    } catch (error, stackTrace) {
      _options?.logger(SentryLevel.warning, '$name failed to be closed.',
          exception: error, stackTrace: stackTrace);
      if (_options?.automatedTestMode == true) {
        rethrow;
      }
    }
  }
}
