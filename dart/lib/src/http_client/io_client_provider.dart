import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import '../protocol.dart';
import '../protocol/sentry_proxy.dart';
import '../sentry_options.dart';
import 'client_provider.dart';

@internal
ClientProvider getClientProvider() {
  return IoClientProvider(
    () {
      return HttpClient();
    },
    (user, pass) {
      return HttpClientBasicCredentials(user, pass);
    },
  );
}

@internal
class IoClientProvider implements ClientProvider {
  final HttpClient Function() _httpClient;
  final HttpClientCredentials Function(String, String) _httpClientCredentials;

  IoClientProvider(this._httpClient, this._httpClientCredentials);

  @override
  Client getClient(SentryOptions options) {
    final proxy = options.proxy;
    if (proxy == null) {
      return Client();
    }
    final pac = proxy.toPacString();
    if (proxy.type == SentryProxyType.socks) {
      options.logger(
        SentryLevel.warning,
        "Setting proxy '$pac' is not supported.",
      );
      return Client();
    }
    options.logger(
      SentryLevel.info,
      "Setting proxy '$pac'",
    );
    final httpClient = _httpClient();
    httpClient.findProxy = (url) => pac;

    final host = proxy.host;
    final port = proxy.port;
    final user = proxy.user;
    final pass = proxy.pass;

    if (host != null && port != null && user != null && pass != null) {
      httpClient.addProxyCredentials(
        host,
        port,
        '',
        _httpClientCredentials(user, pass),
      );
    }
    return IOClient(httpClient);
  }
}
