import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options, this._clientReportRecorder);

  final MethodChannel _channel;
  final SentryOptions _options;
  final ClientReportRecorder _clientReportRecorder;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final clientReport = _clientReportRecorder.flush();
    envelope.addClientReport(clientReport);

    final envelopeData = <int>[];
    await envelope.envelopeStream(_options).forEach(envelopeData.addAll);
    // https://flutter.dev/docs/development/platform-integration/platform-channels#codec
    final args = [Uint8List.fromList(envelopeData)];
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

  @override
  void recordLostEvent(DiscardReason reason, DataCategory category) {
    _clientReportRecorder.recordLostEvent(reason, category);
  }
}
