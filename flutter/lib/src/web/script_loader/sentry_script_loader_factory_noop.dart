import '../../../sentry_flutter.dart';
import 'sentry_script_loader.dart';

SentryScriptLoader createSentryScriptLoader(
    SentryFlutterOptions options, List<Map<String, String>> scripts) {
  return NoopSentryScriptLoader();
}

class NoopSentryScriptLoader implements SentryScriptLoader {
  @override
  Future<void> load() async {
    // no-op
  }
}
