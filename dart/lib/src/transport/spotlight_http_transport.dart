import 'package:http/http.dart';

import '../../sentry.dart';

/// Spotlight HTTP transport class that sends Sentry envelopes to both Sentry and Spotlight.
class SpotlightHttpTransport extends Transport {
  final SentryOptions _options;
  final Transport _transport;

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

    try {
      await _options.httpClient.send(spotlightRequest);
    } catch (e) {
      // Handle any exceptions.
    }
  }
}
