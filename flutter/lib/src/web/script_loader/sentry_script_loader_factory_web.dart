import '../../../sentry_flutter.dart';
import 'sentry_script_loader.dart';
import 'sentry_script_loader_impl.dart';

SentryScriptLoader createSentryScriptLoader(
    SentryFlutterOptions options, List<Map<String, String>> scripts) {
  return SentryScriptLoaderImpl(options, scripts);
}
