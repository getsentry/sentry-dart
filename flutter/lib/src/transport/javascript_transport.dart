import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

class JavascriptEnvelopeTransport implements Transport {
  JavascriptEnvelopeTransport(this._binding, this._options);

  final SentryFlutterOptions _options;
  final SentryWebBinding _binding;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) {
    try {
      _binding.captureEnvelope(envelope);

      return Future.value(SentryId.empty());
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Failed to send envelope',
        exception: exception,
        stackTrace: stackTrace,
      );
      return Future.value(SentryId.empty());
    }
  }
}
