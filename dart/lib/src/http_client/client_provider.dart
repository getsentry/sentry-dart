import 'package:http/http.dart';

import '../sentry_options.dart';

ClientProvider getClientProvider() {
  return ClientProvider();
}

class ClientProvider {
  Client getClient(SentryOptions options) {
    return Client();
  }
}
