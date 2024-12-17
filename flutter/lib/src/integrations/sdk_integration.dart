import '../../sentry_flutter.dart';

export 'native_sdk_integration.dart'
    if (dart.library.html) 'web_sdk_integration.dart'
    if (dart.library.js_interop) 'web_sdk_integration.dart';

typedef SdkIntegration = Integration<SentryFlutterOptions>;
