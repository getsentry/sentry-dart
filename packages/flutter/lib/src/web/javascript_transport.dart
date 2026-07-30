import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

class JavascriptTransport implements Transport {
  JavascriptTransport(this._binding);

  final SentryNativeBinding _binding;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    try {
      await _binding.captureStructuredEnvelope(envelope);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Failed to send envelope',
        error: exception,
        stackTrace: stackTrace,
      );
      return Future.value(SentryId.empty());
    }

    return envelope.header.eventId;
  }
}
