import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import '../utils/transport_utils.dart';
import 'http_transport_request_handler.dart';

import '../noop_client.dart';
import '../protocol.dart';
import '../sentry_options.dart';
import '../sentry_envelope.dart';
import 'transport.dart';
import 'rate_limiter.dart';

/// A transport is in charge of sending the event to the Sentry server.
class HttpTransport implements Transport {
  final SentryOptions _options;

  final RateLimiter _rateLimiter;

  final HttpTransportRequestHandler _requestHandler;

  factory HttpTransport(SentryOptions options, RateLimiter rateLimiter) {
    if (options.httpClient is NoOpClient) {
      options.httpClient = Client();
    }

    return HttpTransport._(options, rateLimiter);
  }

  HttpTransport._(this._options, this._rateLimiter)
      : _requestHandler = HttpTransportRequestHandler(
            _options, Dsn.parse(_options.dsn!).postUri);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final filteredEnvelope = _rateLimiter.filter(envelope);
    if (filteredEnvelope == null) {
      return SentryId.empty();
    }
    filteredEnvelope.header.sentAt = _options.clock();

    final streamedRequest =
        await _requestHandler.createRequest(filteredEnvelope);

    final response = await _options.httpClient
        .send(streamedRequest)
        .then(Response.fromStream);

    _updateRetryAfterLimits(response);

    TransportUtils.logResponse(_options, envelope, response, target: 'Sentry');

    if (response.statusCode == 200) {
      return _parseEventId(response);
    }
    return SentryId.empty();
  }

  SentryId? _parseEventId(Response response) {
    try {
      final eventId = json.decode(response.body)['id'];
      return eventId != null ? SentryId.fromId(eventId) : null;
    } catch (e) {
      _options.logger(SentryLevel.error, 'Error parsing response: $e');
      return null;
    }
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
