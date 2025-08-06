// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryFlutterOptions _options;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final builder = BytesBuilder(copy: false);
    await envelope.envelopeStream(_options).forEach(builder.add);
    final Uint8List envelopeData = builder.takeBytes();

    try {
      await _native.captureEnvelope(envelopeData,
          envelope.containsUnhandledException);
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.error,
        'Failed to save envelope',
        exception: exception,
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
