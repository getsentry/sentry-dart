import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import 'dart:convert';

class FileSystemTransport implements Transport {
  final MethodChannel _channel;
  final SentryOptions _options;

  final _jsonEncoder = const JsonEncoder();

  FileSystemTransport(this._channel, this._options);

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
      'type': event.type,
      // TODO: real length in String
      'length': eventString.length,
    };

    final headerString = _jsonEncoder.convert(headerMap);
    final itemHeaderString = _jsonEncoder.convert(itemHeaderMap);
    final envelopeString = '$headerString\n$itemHeaderString\n$eventString';

    await _channel.invokeMethod('captureEnvelope', <String, dynamic>{
      'event': envelopeString,
    });

    return event.eventId;
  }
}
