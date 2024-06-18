import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'java/sentry_native_java.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

import 'cocoa/sentry_native_cocoa.dart'
  if (dart.library.js_interop) 'cocoa/noop_sentry_native_cocoa.dart';

// import 'cocoa/noop_sentry_native_cocoa.dart'
//   if (dart.library.ffi) 'cocoa/sentry_native_cocoa.dart';

SentryNativeBinding createBinding(PlatformChecker pc, MethodChannel channel) {
  if (pc.platform.isIOS || pc.platform.isMacOS) {
    return SentryNativeCocoa(channel);
  } else if (pc.platform.isAndroid) {
    return SentryNativeJava(channel);
  } else {
    return SentryNativeChannel(channel);
  }
}
