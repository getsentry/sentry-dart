import 'package:flutter/services.dart';

import '../../sentry_flutter.dart';
import 'cocoa/sentry_native_cocoa.dart';
import 'java/sentry_native_java.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

const _defaultChannel = MethodChannel('sentry_flutter');

SentryNativeBinding createBinding(SentryFlutterOptions options,
    {MethodChannel? channel}) {
  final platform = options.platformChecker.platform;
  if (platform.isIOS || platform.isMacOS) {
    return SentryNativeCocoa(options, channel ?? _defaultChannel);
  } else if (platform.isAndroid) {
    return SentryNativeJava(options, channel ?? _defaultChannel);
  } else {
    return SentryNativeChannel(options, channel ?? _defaultChannel);
  }
}
