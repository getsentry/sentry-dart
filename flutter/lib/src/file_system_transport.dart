import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options);

  final MethodChannel _channel;
  final SentryOptions _options;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final eventIdLabel = envelope.header.eventId?.toString() ?? '';
    final args = await compute(
      _convert,
      envelope,
      debugLabel: 'captureEnvelope $eventIdLabel',
    );
    try {
      await _channel.invokeMethod<void>('captureEnvelope', args);
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

  Future<Uint8List> _convert(SentryEnvelope envelope) async {
    final envelopeData = <int>[];
    await envelope.envelopeStream(_options).forEach(envelopeData.addAll);
    // https://flutter.dev/docs/development/platform-integration/platform-channels#codec
    return Uint8List.fromList(envelopeData);
  }
}
