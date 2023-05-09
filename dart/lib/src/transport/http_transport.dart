import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../client_reports/client_report_recorder.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';
import 'noop_encode.dart' if (dart.library.io) 'encode.dart';
import '../noop_client.dart';
import '../protocol.dart';
import '../sentry_options.dart';
import '../sentry_envelope.dart';
import 'transport.dart';
import 'rate_limiter.dart';

/// A transport is in charge of sending the event to the Sentry server.
class HttpTransport implements Transport {
  final SentryOptions _options;

  final Dsn _dsn;

  final RateLimiter _rateLimiter;

  final ClientReportRecorder _recorder;

  late _CredentialBuilder _credentialBuilder;

  final Map<String, String> _headers;

  factory HttpTransport(SentryOptions options, RateLimiter rateLimiter) {
    if (options.httpClient is NoOpClient) {
      options.httpClient = Client();
    }

    return HttpTransport._(options, rateLimiter);
  }

  HttpTransport._(this._options, this._rateLimiter)
      : _dsn = Dsn.parse(_options.dsn!),
        _recorder = _options.recorder,
        _headers = _buildHeaders(
          _options.platformChecker.isWeb,
          _options.sentryClientName,
        ) {
    _credentialBuilder = _CredentialBuilder(
      _dsn,
      _options.sentryClientName,
    );
  }

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final filteredEnvelope = _rateLimiter.filter(envelope);
    if (filteredEnvelope == null) {
      return SentryId.empty();
    }

    final streamedRequest = await _createStreamedRequest(filteredEnvelope);
    final response = await _options.httpClient
        .send(streamedRequest)
        .then(Response.fromStream);

    _updateRetryAfterLimits(response);

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

      if (response.statusCode >= 400 && response.statusCode != 429) {
        _recorder.recordLostEvent(
            DiscardReason.networkError, DataCategory.error);
      }

      return SentryId.empty();
    } else {
      _options.logger(
        SentryLevel.debug,
        'Envelope ${envelope.header.eventId ?? "--"} was sent successfully.',
      );
    }

    final eventId = json.decode(response.body)['id'];
    if (eventId == null) {
      return null;
    }
    return SentryId.fromId(eventId);
  }

  Future<StreamedRequest> _createStreamedRequest(
      SentryEnvelope envelope) async {
    final streamedRequest = StreamedRequest('POST', _dsn.postUri);

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

  void _updateRetryAfterLimits(Response response) {
    // seconds
    final retryAfterHeader = response.headers['Retry-After'];

    // X-Sentry-Rate-Limits looks like: seconds:categories:scope
    // it could have more than one scope so it looks like:
    // quota_limit, quota_limit, quota_limit

    // a real example: 50:transaction:key, 2700:default;error;security:organization
    // 50::key is also a valid case, it means no categories and it should apply to all of them
    final sentryRateLimitHeader = response.headers['X-Sentry-Rate-Limits'];
    _rateLimiter.updateRetryAfterLimits(
        sentryRateLimitHeader, retryAfterHeader, response.statusCode);
  }
}

class _CredentialBuilder {
  final String _authHeader;

  _CredentialBuilder._(String authHeader)
      : _authHeader = authHeader;

  factory _CredentialBuilder(
      Dsn dsn, String sdkIdentifier) {
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
        <String, String>{
          'X-Sentry-Auth': _authHeader
        },
      );
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
