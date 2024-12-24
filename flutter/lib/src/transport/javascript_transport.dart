import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';

class JavascriptTransport implements Transport {
  JavascriptTransport(this._binding, this._options);

  final SentryFlutterOptions _options;
  final SentryNativeBinding _binding;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    try {
      await _binding.captureEnvelopeObject(envelope);
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Failed to send envelope',
        exception: exception,
        stackTrace: stackTrace,
      );
      return Future.value(SentryId.empty());
    }

    return envelope.header.eventId;
  }
}
