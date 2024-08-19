import 'dart:async';

import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

/// Initializes the Javascript SDK with the given options.
class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  final SentryWebBinding _webBinding;
  SentryFlutterOptions? _options;

  WebSdkIntegration(this._webBinding);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _options = options;

    try {
      _webBinding.init(options);
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
    try {
      _webBinding.close();
    } catch (exception, stackTrace) {
      _options?.logger(
        SentryLevel.fatal,
        'WebSdkIntegration failed to be closed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
