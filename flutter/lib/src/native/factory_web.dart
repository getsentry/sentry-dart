import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'sentry_native_binding.dart';

// This isn't actually called, see SentryFlutter.init()
SentryNativeBinding createBinding(PlatformChecker pc, MethodChannel channel) {
  throw UnsupportedError("Native binding is not supported on this platform.");
}
