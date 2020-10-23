import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sentry/src/utils.dart';

import '../protocol.dart';
import '../sentry_options.dart';
import 'body_encoder_browser.dart' if (dart.library.io) 'body_encoder.dart';

typedef BodyEncoder = List<int> Function(
  Map<String, dynamic> data,
  Map<String, String> headers, {
  bool compressPayload,
});

/// A transport is in charge of sending the event to the Sentry server.
class Transport {
  final SentryOptions _options;

  @visibleForTesting
  final Dsn dsn;

  /// Use for browser stacktrace
  final String _origin;

  CredentialBuilder _credentialBuilder;

  final Map<String, String> _headers;

  Transport({
    @required SentryOptions options,
    @required String sdkIdentifier,
    String origin,
  })  : _options = options,
        _origin = origin,
        dsn = Dsn.parse(options.dsn),
        _headers = _buildHeaders(sdkIdentifier: sdkIdentifier) {
    _credentialBuilder = CredentialBuilder(
      dsn: Dsn.parse(options.dsn),
      clientId: sdkIdentifier,
      clock: options.clock,
    );
  }

  Future<SentryId> send(SentryEvent event) async {
    final data = _getEventData(event);

    final body = bodyEncoder(
      data,
      _headers,
      compressPayload: _options.compressPayload,
    );

    final response = await _options.httpClient.post(
      dsn.postUri,
      headers: _credentialBuilder.configure(_headers),
      body: body,
    );

    if (response.statusCode != 200) {
      return SentryId.empty();
    }

    final eventId = json.decode(response.body)['id'];
    return eventId != null ? SentryId.fromId(eventId) : SentryId.empty();
  }

  Map<String, dynamic> _getEventData(SentryEvent event) {
    final data = event.toJson(origin: _origin);

    // TODO add this attributes to event in client
    if (_options.environmentAttributes != null) {
      mergeAttributes(_options.environmentAttributes.toJson(), into: data);
    }

    return data;
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
