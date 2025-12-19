// Web stub for sentry_native_java.dart
// This file provides only the parts needed for being able to compile on Web
// without importing JNI or other FFI dependencies.

import 'package:meta/meta.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

@visibleForTesting
extension ReplaySizeAdjustment on double {
  double adjustReplaySizeToBlockSize() {
    return 0;
  }
}

/// Stub class for web compilation. Tests using this run only on VM.
class SentryNativeJava {
  SentryNativeJava(SentryFlutterOptions options);
}
