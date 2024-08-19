import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

SentryWebBinding createBinding(SentryFlutterOptions options) {
  throw UnsupportedError("Web binding is not supported on this platform.");
}
