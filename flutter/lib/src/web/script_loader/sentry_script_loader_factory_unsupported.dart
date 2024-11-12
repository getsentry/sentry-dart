import '../../../sentry_flutter.dart';
import 'sentry_script_loader.dart';

SentryScriptLoader createSentryScriptLoader(
    SentryFlutterOptions options, List<Map<String, String>> scripts) {
  throw UnsupportedError(
      "Sentry script loader is not supported on this platform.");
}
