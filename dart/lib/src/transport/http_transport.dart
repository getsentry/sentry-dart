import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../protocol.dart';
import '../sentry_options.dart';
import '../utils.dart';
import 'noop_encode.dart' if (dart.library.io) 'encode.dart';
import 'transport.dart';

/// A transport is in charge of sending the event to the Sentry server.
class HttpTransport implements Transport {
  final SentryOptions _options;

  final Dsn _dsn;

  /// Use for browser stacktrace
  final String _origin;

  CredentialBuilder _credentialBuilder;

  final Map<String, String> _headers;

  HttpTransport({@required SentryOptions options, String origin})
      : _options = options,
        _origin = origin,
        _dsn = Dsn.parse(options.dsn),
        _headers = _buildHeaders(sdkIdentifier: options.sdk.identifier) {
    _credentialBuilder = CredentialBuilder(
      dsn: Dsn.parse(options.dsn),
      clientId: options.sdk.identifier,
      clock: options.clock,
    );
  }

  @override
  Future<SentryId> send(SentryEvent event) async {
    final data = event.toJson(origin: _origin);

    final body = _bodyEncoder(
      data,
      _headers,
      compressPayload: _options.compressPayload,
    );

    final response = await _options.httpClient.post(
      _dsn.postUri,
      headers: _credentialBuilder.configure(_headers),
      body: body,
    );

    if (response.statusCode != 200) {
      // body guard to not log the error as it has performance impact to allocate
      // the body String.
      if (_options.debug) {
        _options.logger(
          SentryLevel.error,
          'API returned an error, statusCode = ${response.statusCode}, '
          'body = ${response.body}',
        );
      }
      return SentryId.empty();
    } else {
      _options.logger(
        SentryLevel.debug,
        'Event ${event.eventId} was sent suceffully.',
      );
    }

    final eventId = json.decode(response.body)['id'];
    return eventId != null ? SentryId.fromId(eventId) : SentryId.empty();
  }

  List<int> _bodyEncoder(
    Map<String, dynamic> data,
    Map<String, String> headers, {
    bool compressPayload,
  }) {
    // [SentryIOClient] implement gzip compression
    // gzip compression is not available on browser
    var body = utf8.encode(json.encode(data));
    if (compressPayload) {
      body = compressBody(body, headers);
    }
    return body;
  }
}

class CredentialBuilder {
  final String _authHeader;

  final ClockProvider clock;

  int get timestamp => clock().millisecondsSinceEpoch;

  CredentialBuilder({@required Dsn dsn, String clientId, @required this.clock})
      : _authHeader = buildAuthHeader(
          publicKey: dsn.publicKey,
          secretKey: dsn.secretKey,
          clientId: clientId,
        );

  static String buildAuthHeader({
    String publicKey,
    String secretKey,
    String clientId,
  }) {
    var header = 'Sentry sentry_version=6, sentry_client=$clientId, '
        'sentry_key=${publicKey}';

    if (secretKey != null) {
      header += ', sentry_secret=${secretKey}';
    }

    return header;
  }

  Map<String, dynamic> configure(Map<String, dynamic> headers) {
    return headers
      ..addAll(
        <String, String>{
          'X-Sentry-Auth': '$_authHeader, sentry_timestamp=${timestamp}'
        },
      );
  }
}

Map<String, String> _buildHeaders({String sdkIdentifier}) {
  final headers = {'Content-Type': 'application/json'};
  // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
  // for web it use browser user agent
  if (!isWeb) {
    headers['User-Agent'] = sdkIdentifier;
  }
  return headers;
}
