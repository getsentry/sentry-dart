import 'dart:async';

import '../../sentry_flutter.dart';
import '../native/sentry_native_invoker.dart';
import 'sentry_js_binding.dart';

abstract class SentryWebBinding {
  FutureOr<void> init();
  FutureOr<void> close();
}

class SentryWeb with SentryNativeSafeInvoker implements SentryWebBinding {
  SentryWeb(this._binding, this._options);

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;

  @override
  FutureOr<void> init() {
    final Map<String, dynamic> mapOptions = {
      'dsn': _options.dsn,
      'debug': _options.debug,
      'environment': _options.environment,
      'release': _options.release,
      'dist': _options.dist,
      'sampleRate': _options.sampleRate,
      'attachStacktrace': _options.attachStacktrace,
      'maxBreadcrumbs': _options.maxBreadcrumbs,
      // using defaultIntegrations ensures that we can control which integrations are added
      'defaultIntegrations': [],
    };
    _binding.init(mapOptions);
  }

  @override
  FutureOr<void> close() {}

  @override
  SentryFlutterOptions get options => _options;
}
