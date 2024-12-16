import '../../sentry_flutter.dart';
import '../web/sentry_js_binding.dart';
import '../web/sentry_web.dart';
import 'sentry_native_binding.dart';

SentryNativeBinding createBinding(SentryFlutterOptions options) {
  final binding = createJsBinding();
  print('create web');
  return SentryWeb(binding, options);
}
