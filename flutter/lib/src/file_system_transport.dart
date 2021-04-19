import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options);

  final MethodChannel _channel;
  final SentryOptions _options;

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    final envelopeData = <int>[];
    await envelope.envelopeStream().forEach(envelopeData.addAll);

    final envelopeString = utf8.decode(envelopeData);

    final args = [envelopeString];
    try {
      await _channel.invokeMethod<void>('captureEnvelope', args);
    } catch (error) {
      _options.logger(
        SentryLevel.error,
        'Failed to save envelope: $error',
      );
      return SentryId.empty();
    }

    return envelope.header.eventId ?? SentryId.empty();
  }
}
