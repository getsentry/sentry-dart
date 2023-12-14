import 'package:http/http.dart';

import '../../sentry.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';

/// Spotlight HTTP transport class that sends Sentry envelopes to both Sentry and Spotlight.
class SpotlightHttpTransport extends Transport {
  final SentryOptions _options;
  final Transport _transport;
  final Map<String, String> _headers = {'Content-Type': 'application/x-sentry-envelope'};

  SpotlightHttpTransport(this._options, this._transport);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    await _sendToSpotlight(envelope);
    return _transport.send(envelope);
  }

  Future<void> _sendToSpotlight(SentryEnvelope envelope) async {
    final Uri spotlightUri = Uri.parse(_options.spotlightUrl);
    final StreamedRequest spotlightRequest =
        StreamedRequest('POST', spotlightUri);

    envelope
        .envelopeStream(_options)
        .listen(spotlightRequest.sink.add)
        .onDone(spotlightRequest.sink.close);

    spotlightRequest.headers.addAll(_headers);

    final response = await _options.httpClient
        .send(spotlightRequest)
        .then(Response.fromStream);

    if (response.statusCode != 200) {
      // body guard to not log the error as it has performance impact to allocate
      // the body String.
      if (_options.debug) {
        _options.logger(
          SentryLevel.error,
          'Spotlight Sidecar API returned an error, statusCode = ${response.statusCode}, '
          'body = ${response.body}',
        );
        print('body = ${response.request}');
      }

      if (response.statusCode >= 400 && response.statusCode != 429) {
        _options.recorder.recordLostEvent(
            DiscardReason.networkError, DataCategory.error);
      }
    } else {
      _options.logger(
        SentryLevel.debug,
        'Envelope ${envelope.header.eventId ?? "--"} was sent successfully to spotlight ($spotlightUri)',
      );
    }
  }
}
