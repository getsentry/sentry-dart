import '../../../sentry_flutter.dart';
import 'script_dom_api.dart';
import 'sentry_script_loader.dart';

Future<void> loadScript(String src, SentryOptions options,
    {String? integrity,
    String trustedTypePolicyName = defaultTrustedPolicyName}) async {}

List<SentryScriptElement> fetchScripts(String query) => [];
