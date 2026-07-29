import 'dart:typed_data';

import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';
import 'utils/internal_logger.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryFlutterOptions _options;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bytesBuilder = BytesBuilder(copy: false);
    await envelope.envelopeStream(_options).forEach(bytesBuilder.add);
    final envelopeData = bytesBuilder.takeBytes();

    try {
      await _native.captureEnvelope(
        envelopeData,
        envelope.containsUnhandledException,
      );
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Failed to save envelope',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
      return SentryId.empty();
    }

    return envelope.header.eventId;
  }
}
