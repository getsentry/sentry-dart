import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'base.dart';

/// Implemented in `browser_client.dart` and `io_client.dart`.
SentryClient createSentryClient({
  @required String dsn,
  Event environmentAttributes,
  bool compressPayload,
  Client httpClient,
  dynamic clock,
  UuidGenerator uuidGenerator,
}) =>
    throw UnsupportedError(
        'Cannot create a client without dart:html or dart:io.');
