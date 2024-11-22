import '../../../sentry_flutter.dart';
import 'sentry_js_bridge.dart';

abstract class SentryJsBinding {
  void init();
}

class SentryNativeJs implements SentryJsBinding {
  SentryNativeJs(this._options, {SentryJsBridge? bridge})
      : _bridge = bridge ?? createSentryJsBridge();

  final SentryFlutterOptions _options;
  final SentryJsBridge _bridge;

  @override
  void init() {
    final Map<String, dynamic> options = {
      'dsn': _options.dsn,
      'debug': _options.debug,
      'environment': _options.environment,
      'release': _options.release,
      'dist': _options.dist,
      'sampleRate': _options.sampleRate,
      'autoSessionTracking': _options.enableAutoSessionTracking,
      'attachStacktrace': _options.attachStacktrace,
      'maxBreadcrumbs': _options.maxBreadcrumbs,
      // using defaultIntegrations ensures that we can control which integrations are added
      'defaultIntegrations': [],
    };
    _bridge.init(options);
  }
}
