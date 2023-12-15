import 'package:http/http.dart';
import 'http_transport_request_creator.dart';

import '../../sentry.dart';
import '../client_reports/discard_reason.dart';
import '../noop_client.dart';
import 'data_category.dart';

/// Spotlight HTTP transport decorator that sends Sentry envelopes to both Sentry and Spotlight.
class SpotlightHttpTransport extends Transport {
  final SentryOptions _options;
  final Transport _transport;
  final HttpTransportRequestCreator _requestCreator;

  factory SpotlightHttpTransport(SentryOptions options, Transport transport) {
    if (options.httpClient is NoOpClient) {
      options.httpClient = Client();
    }
    return SpotlightHttpTransport._(options, transport);
  }

  SpotlightHttpTransport._(this._options, this._transport)
      : _requestCreator = HttpTransportRequestCreator(
            _options, Uri.parse(_options.spotlightUrl));

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    await _sendToSpotlight(envelope);
    return _transport.send(envelope);
  }

  Future<void> _sendToSpotlight(SentryEnvelope envelope) async {
    envelope.header.sentAt = _options.clock();

    // Screenshots do not work currently https://github.com/getsentry/spotlight/issues/274
    envelope.items
        .removeWhere((element) => element.header.contentType == 'image/png');

    final spotlightRequest = await _requestCreator.createRequest(envelope);

    final response = await _options.httpClient
        .send(spotlightRequest)
        .then(Response.fromStream);

    if (response.statusCode != 200) {
      // body guard to not log the error as it has performance impact to allocate
      // the body String.
      if (_options.debug) {
        _options.logger(
          SentryLevel.error,
          'Spotlight returned an error, statusCode = ${response.statusCode}, '
          'body = ${response.body}',
        );
      }

      if (response.statusCode >= 400 && response.statusCode != 429) {
        _options.recorder
            .recordLostEvent(DiscardReason.networkError, DataCategory.error);
      }
    } else {
      _options.logger(
        SentryLevel.debug,
        'Envelope ${envelope.header.eventId ?? "--"} was sent successfully to Spotlight (${_options.spotlightUrl})',
      );
    }
  }
}
