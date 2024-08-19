import 'dart:async';

import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

class WebSdkIntegration implements Integration<SentryFlutterOptions> {
  final SentryWebBinding _binding;
  SentryFlutterOptions? _options;

  WebSdkIntegration(this._binding);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _options = options;

    try {
      _binding.init(options);
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
      _binding.close();
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
