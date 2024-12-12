import '../../sentry_flutter.dart';
import 'c/sentry_native.dart';
import 'cocoa/sentry_native_cocoa.dart';
import 'java/sentry_native_java.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_channel.dart';

SentryNativeBinding createBinding(SentryFlutterOptions options) {
  final platform = options.platformChecker.platform;
  if (platform.isIOS || platform.isMacOS) {
    return SentryNativeCocoa(options);
  } else if (platform.isAndroid) {
    return SentryNativeJava(options);
  } else if (platform.isWindows || platform.isLinux) {
    return SentryNative(options);
  } else {
    return SentryNativeChannel(options);
  }
}
