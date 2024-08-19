import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

class JavascriptEventTransport implements EventTransport {
  final SentryWebBinding _binding;

  JavascriptEventTransport(this._binding);

  @override
  Future<SentryId?> sendEvent(SentryEvent event) {
    _binding.captureEvent(event);

    return Future.value(event.eventId);
  }
}

class JavascriptEnvelopeTransport implements Transport {
  final SentryWebBinding _binding;

  JavascriptEnvelopeTransport(this._binding);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) {
    _binding.captureEnvelope(envelope);

    return Future.value(SentryId.empty());
  }
}
