import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../web/sentry_js_bundle.dart';

Integration<SentryFlutterOptions> createSdkIntegration(
    SentryNativeBinding native) {
  return WebSdkIntegration(native);
}

class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  WebSdkIntegration(this._web);

  final SentryNativeBinding _web;
  SentryFlutterOptions? _options;

  @internal
  static const name = 'webSdkIntegration';

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      _options = options;
      final scripts = options.platformChecker.isDebugMode()
          ? debugScripts
          : productionScripts;
      await options.scriptLoader.loadWebSdk(scripts);
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
    await _options?.scriptLoader.close();
  }
}
