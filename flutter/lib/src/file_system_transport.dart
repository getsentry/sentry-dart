// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
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
    final envelopeData = await compute(_convert, _ConvertMessage(envelope, _options.maxAttachmentSize));
    final args = [envelopeData];
    try {
      await _channel.invokeMethod('captureEnvelope', args);
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

  static Future<Uint8List> _convert(_ConvertMessage message) async {
    final envelopeData = <int>[];
    await message.envelope.envelopeStream(message.maxAttachmentSize).forEach(envelopeData.addAll);
    //https://flutter.dev/docs/development/platform-integration/platform-channels#codec
    return Uint8List.fromList(envelopeData);
  }
}

class _ConvertMessage {
  final SentryEnvelope envelope;
  final int maxAttachmentSize;

  _ConvertMessage(this.envelope, this.maxAttachmentSize);
}
