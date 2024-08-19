import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';
import 'sentry_web_interop.dart';

SentryWebBinding createBinding(SentryFlutterOptions options) {
  return SentryWebInterop(options);
}
