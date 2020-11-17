import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options);

  final MethodChannel _channel;
  final SentryOptions _options;

  final _jsonEncoder = const JsonEncoder();

  @override
  Future<SentryId> send(SentryEvent event) async {
    final headerMap = {
      'event_id': event.eventId.toString(),
      'sdk': _options.sdk.toJson()
    };

    final eventMap = event.toJson();

    final eventString = _jsonEncoder.convert(eventMap);

    final itemHeaderMap = {
      'content_type': 'application/json',
      'type': 'event',
      'length': eventString.length,
    };

    final headerString = _jsonEncoder.convert(headerMap);
    final itemHeaderString = _jsonEncoder.convert(itemHeaderMap);
    final envelopeString = '$headerString\n$itemHeaderString\n$eventString';

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

    return event.eventId;
  }
}
