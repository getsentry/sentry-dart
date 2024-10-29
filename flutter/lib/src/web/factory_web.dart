import 'sentry_js_bridge.dart';

import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';
import 'sentry_script_loader.dart';
import 'sentry_web_interop.dart';

SentryWebBinding createBinding(SentryFlutterOptions options) {
  return SentryWebInterop(SentryJsSdk(), options, SentryScriptLoader(options));
}
