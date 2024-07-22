import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';

import '../protocol.dart';
import '../sentry_options.dart';

Client proxyClient(String httpProxy, SentryOptions options) {
  options.logger(
    SentryLevel.info,
    "Setting proxy '$httpProxy'",
  );
  final httpClient = HttpClient();
  httpClient.findProxy = (url) => httpProxy;
  final ioClient = IOClient(httpClient);
  return ioClient;
}
