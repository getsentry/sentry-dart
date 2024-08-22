import 'sentry_js_bridge.dart';

import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';
import 'sentry_web_interop.dart';

SentryWebBinding createBinding(SentryFlutterOptions options,
    {SentryJsApi? jsBridge}) {
  return SentryWebInterop(jsBridge ?? SentryJsWrapper(), options);
}
