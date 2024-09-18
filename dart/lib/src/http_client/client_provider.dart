import 'package:meta/meta.dart';
import 'package:http/http.dart';

import '../sentry_options.dart';

@internal
ClientProvider getClientProvider() {
  return ClientProvider();
}

@internal
class ClientProvider {
  Client getClient(SentryOptions options) {
    return Client();
  }
}
