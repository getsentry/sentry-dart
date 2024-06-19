import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'sentry_native_binding.dart';

// This isn't actually called, see SentryFlutter.init()
SentryNativeBinding createBinding(SentryFlutterOptions options,
    {MethodChannel channel = const MethodChannel('sentry_flutter')}) {
  throw UnsupportedError("Native binding is not supported on this platform.");
}
