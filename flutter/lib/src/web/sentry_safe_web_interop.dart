import 'sentry_js_bridge.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_invoker.dart';

class SentrySafeMethodChannel with SentryNativeSafeInvoker {
  @override
  final SentryFlutterOptions options;

  final SentryJsBridge _bridge;

  SentrySafeMethodChannel(this._bridge, this.options);
}
