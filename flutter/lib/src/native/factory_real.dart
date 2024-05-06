import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'cocoa/sentry_native_cocoa.dart';
import 'java/sentry_native_java.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

SentryNativeBinding createBinding(PlatformChecker pc, MethodChannel channel) {
  if (pc.platform.isIOS || pc.platform.isMacOS) {
    return SentryNativeCocoa(channel);
  } else if (pc.platform.isAndroid) {
    return SentryNativeJava(channel);
  } else {
    return SentryNativeChannel(channel);
  }
}
