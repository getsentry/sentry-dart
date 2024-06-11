import 'package:flutter/services.dart';

import 'sentry_native_binding.dart';

// ignore: implementation_imports
import 'package:sentry/src/platform/platform.dart';

// This isn't actually called, see SentryFlutter.init()
SentryNativeBinding createBinding(Platform _, MethodChannel __) {
  throw UnsupportedError("Native binding is not supported on this platform.");
}
