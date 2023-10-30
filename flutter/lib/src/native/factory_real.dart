import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'cocoa/sentry_native_cocoa.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

SentryNativeBinding createBinding(PlatformChecker pc, MethodChannel channel) {
  if (pc.platform.isIOS || pc.platform.isMacOS) {
    return SentryNativeCocoa(channel);
  } else {
    return SentryNativeChannel(channel);
  }
}
