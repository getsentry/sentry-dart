import '../../sentry_flutter.dart';
import 'sentry_native_binding.dart';

// This isn't actually called, see SentryFlutter.init()
SentryNativeBinding createBinding(SentryFlutterOptions options) {
  throw UnsupportedError("Native binding is not supported on this platform.");
}
