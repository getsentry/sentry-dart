import 'dart:async';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'noop_encode.dart' if (dart.library.io) 'encode.dart';
import '../protocol.dart';
import '../sentry_options.dart';
import '../sentry_envelope.dart';

@internal
class HttpTransportRequestHandler {
  final SentryOptions _options;
  final Dsn _dsn;
  final Map<String, String> _headers;
  final Uri _requestUri;
  late _CredentialBuilder _credentialBuilder;

  HttpTransportRequestHandler(this._options, this._requestUri)
      : _dsn = Dsn.parse(_options.dsn!),
        _headers = _buildHeaders(
          _options.platformChecker.isWeb,
          _options.sentryClientName,
        ) {
    _credentialBuilder = _CredentialBuilder(
      _dsn,
      _options.sentryClientName,
    );
  }

  Future<StreamedRequest> createRequest(SentryEnvelope envelope) async {
    final streamedRequest = StreamedRequest('POST', _requestUri);

    if (_options.compressPayload) {
      final compressionSink = compressInSink(streamedRequest.sink, _headers);
      envelope
          .envelopeStream(_options)
          .listen(compressionSink.add)
          .onDone(compressionSink.close);
    } else {
      envelope
          .envelopeStream(_options)
          .listen(streamedRequest.sink.add)
          .onDone(streamedRequest.sink.close);
    }

    streamedRequest.headers.addAll(_credentialBuilder.configure(_headers));
    return streamedRequest;
  }
}

Map<String, String> _buildHeaders(bool isWeb, String sdkIdentifier) {
  final headers = {'Content-Type': 'application/x-sentry-envelope'};
  // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
  // for web it use browser user agent
  if (!isWeb) {
    headers['User-Agent'] = sdkIdentifier;
  }
  return headers;
}

class _CredentialBuilder {
  final String _authHeader;

  _CredentialBuilder._(String authHeader) : _authHeader = authHeader;

  factory _CredentialBuilder(Dsn dsn, String sdkIdentifier) {
    final authHeader = _buildAuthHeader(
      publicKey: dsn.publicKey,
      secretKey: dsn.secretKey,
      sdkIdentifier: sdkIdentifier,
    );

    return _CredentialBuilder._(authHeader);
  }

  static String _buildAuthHeader({
    required String publicKey,
    String? secretKey,
    required String sdkIdentifier,
  }) {
    var header = 'Sentry sentry_version=7, sentry_client=$sdkIdentifier, '
        'sentry_key=$publicKey';

    if (secretKey != null) {
      header += ', sentry_secret=$secretKey';
    }

    return header;
  }

  Map<String, String> configure(Map<String, String> headers) {
    return headers
      ..addAll(
        <String, String>{'X-Sentry-Auth': _authHeader},
      );
  }
}
