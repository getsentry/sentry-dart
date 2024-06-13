import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'cocoa/sentry_native_cocoa.dart';
import 'java/sentry_native_java.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

SentryNativeBinding createBinding(SentryFlutterOptions options,
    {MethodChannel channel = const MethodChannel('sentry_flutter')}) {
  final platform = options.platformChecker.platform;
  if (platform.isIOS || platform.isMacOS) {
    return SentryNativeCocoa(options, channel);
  } else if (platform.isAndroid) {
    return SentryNativeJava(options, channel);
  } else {
    return SentryNativeChannel(options, channel);
  }
}
