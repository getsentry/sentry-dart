import 'package:http/http.dart';

import '../protocol.dart';
import '../sentry_options.dart';

Client proxyClient(String httpProxy, SentryOptions options) {
  options.logger(
    SentryLevel.warning,
    "Setting proxy '$httpProxy' only supported on io platforms.",
  );
  return Client();
}
