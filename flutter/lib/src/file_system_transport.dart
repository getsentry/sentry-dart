// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry/src/transport/http_transport.dart';
import 'native/sentry_native_binding.dart';
import 'package:js/js_util.dart' as js_util;

import 'web/sentry_js_bridge.dart';
import 'web/sentry_web_binding.dart';

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

class EventTransportAdapter implements Transport {
  final EventTransport _eventTransport;
  final Transport _envelopeTransport;

  EventTransportAdapter(this._eventTransport, this._envelopeTransport);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final item in envelope.items) {
      final object = item.originalObject;
      if (item.header.type == 'event' && object is SentryEvent) {
        return _eventTransport.sendEvent(object);
      }
    }
    // If no event is found in the envelope, return an empty ID
    return SentryId.empty();
  }
}

class JavascriptEventTransport implements EventTransport {
  final SentryWebBinding _binding;

  JavascriptEventTransport(this._binding);

  @override
  Future<SentryId?> sendEvent(SentryEvent event) {
    _binding.captureEvent(event);

    return Future.value(event.eventId);
  }
}

class JavascriptEnvelopeTransport implements Transport {
  final SentryWebBinding _binding;

  JavascriptEnvelopeTransport(this._binding);

  @override
  Future<SentryId?> send(SentryEnvelope envelope) {
    _binding.captureEnvelope(envelope);

    return Future.value(SentryId.empty());
  }
}
