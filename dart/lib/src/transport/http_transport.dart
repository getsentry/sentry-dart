import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'http_transport_request_creator.dart';

import '../client_reports/client_report_recorder.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';
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

  late HttpTransportRequestCreator _httpTransportRequestCreator;

  factory HttpTransport(SentryOptions options, RateLimiter rateLimiter) {
    if (options.httpClient is NoOpClient) {
      options.httpClient = Client();
    }

    return HttpTransport._(options, rateLimiter);
  }

  HttpTransport._(this._options, this._rateLimiter)
      : _dsn = Dsn.parse(_options.dsn!),
        _recorder = _options.recorder {
    _httpTransportRequestCreator = HttpTransportRequestCreator(_options, _dsn.postUri);
  }

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final filteredEnvelope = _rateLimiter.filter(envelope);
    if (filteredEnvelope == null) {
      return SentryId.empty();
    }
    filteredEnvelope.header.sentAt = _options.clock();

    final streamedRequest = await _httpTransportRequestCreator.createRequest(filteredEnvelope);
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
