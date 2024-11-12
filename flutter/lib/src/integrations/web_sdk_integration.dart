import 'dart:async';

import '../../sentry_flutter.dart';
import '../web/sentry_script_loader.dart';

/// Initializes the Javascript SDK with the given options.
class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  WebSdkIntegration(this._scriptLoader);

  final SentryScriptLoader _scriptLoader;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      await _scriptLoader.loadScripts();

      options.sdk.addIntegration('WebSdkIntegration');
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        'WebSdkIntegration failed to be installed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  FutureOr<void> close() {
    // no-op for now
  }
}
