import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../web/script_loader/sentry_script_loader.dart';
import '../web/sentry_js_bundle.dart';

class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  WebSdkIntegration(this._web, this._scriptLoader);

  final SentryScriptLoader _scriptLoader;
  final SentryNativeBinding _web;

  @internal
  static const name = 'webSdkIntegration';

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      final scripts = options.platformChecker.isDebugMode()
          ? debugScripts
          : productionScripts;
      await _scriptLoader.loadWebSdk(scripts);
      await _web.init(hub);

      options.sdk.addIntegration(name);
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        '$name failed to be installed',
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
    await _web.close();
    await _scriptLoader.close();
  }
}
