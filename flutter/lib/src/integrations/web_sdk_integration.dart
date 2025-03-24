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
