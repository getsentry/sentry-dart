import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options);

  final MethodChannel _channel;
  final SentryOptions _options;

  @override
  Future<SentryId?> sendSentryEvent(SentryEvent event) async {
    final envelope = SentryEnvelope.fromEvent(event, _options.sdk);
    return await sendSentryEnvelope(envelope);
  }

  @override
  Future<SentryId?> sendSentryEnvelope(SentryEnvelope envelope) async {
    final envelopeData = await envelope.serialize();
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

    return envelope.header.eventId;
  }
}
