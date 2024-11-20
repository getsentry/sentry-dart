import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../web/script_loader/sentry_script_loader.dart';

class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  WebSdkIntegration(this._scriptLoader);

  final SentryScriptLoader _scriptLoader;

  @internal
  static const name = 'webSdkIntegration';

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      await _scriptLoader.load();

      options.sdk.addIntegration(name);
    } catch (exception, stackTrace) {
      if (options.automatedTestMode) {
        rethrow;
      }
      options.logger(
        SentryLevel.fatal,
        '$name failed to be installed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  FutureOr<void> close() {
    // no-op
  }
}
