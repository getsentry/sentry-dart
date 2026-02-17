import 'package:http/http.dart';
import '../utils/transport_utils.dart';
import 'http_transport_request_handler.dart';

import '../../sentry.dart';
import '../noop_client.dart';
import '../http_client/client_provider.dart'
    if (dart.library.io) '../http_client/io_client_provider.dart';

/// Spotlight HTTP transport decorator that sends Sentry envelopes to both Sentry and Spotlight.
/// This will be used on platforms that do not have native SDK support.
/// Platforms with native SDK support will configure spotlight directly in the native SDK options.
class SpotlightHttpTransport extends Transport {
  final SentryOptions _options;
  final Transport _transport;
  final HttpTransportRequestHandler _requestHandler;

  factory SpotlightHttpTransport(SentryOptions options, Transport transport) {
    if (options.httpClient is NoOpClient) {
      options.httpClient = getClientProvider().getClient(options);
    }
    return SpotlightHttpTransport._(options, transport);
  }

  SpotlightHttpTransport._(this._options, this._transport)
      : _requestHandler = HttpTransportRequestHandler(_options,
            Uri.parse(_options.spotlight.url ?? _defaultSpotlightUrl()));

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    try {
      await _sendToSpotlight(envelope);
    } catch (e) {
      _options.log(
          SentryLevel.warning, 'Failed to send envelope to Spotlight: $e');
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
    return _transport.send(envelope);
  }

  Future<void> _sendToSpotlight(SentryEnvelope envelope) async {
    envelope.header.sentAt = _options.clock();

    final spotlightRequest = await _requestHandler.createRequest(envelope);

    final response = await _options.httpClient
        .send(spotlightRequest)
        .then(Response.fromStream);

    TransportUtils.logResponse(envelope, response, target: 'Spotlight');
  }
}

String _defaultSpotlightUrl() {
  return 'http://localhost:8969/stream';
}
