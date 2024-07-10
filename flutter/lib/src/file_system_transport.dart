// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

import 'native/sentry_native_binding.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryOptions _options;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final envelopeData = <int>[];
    await envelope.envelopeStream(_options).forEach(envelopeData.addAll);
    try {
      // TODO avoid copy
      await _native.captureEnvelope(Uint8List.fromList(envelopeData),
          envelope.containsUnhandledException);
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Failed to save envelope',
        exception: exception,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    }

    return envelope.header.eventId;
  }
}
