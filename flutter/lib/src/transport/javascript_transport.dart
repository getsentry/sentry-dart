import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

class JavascriptEnvelopeTransport implements Transport {
  final SentryWebBinding _binding;

  JavascriptEnvelopeTransport(this._binding);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) {
    _binding.captureEnvelope(envelope);

    return Future.value(SentryId.empty());
  }
}
