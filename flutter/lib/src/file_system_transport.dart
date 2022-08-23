import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FileSystemTransport implements Transport {
  FileSystemTransport(this._channel, this._options);

  final MethodChannel _channel;
  final SentryOptions _options;

  // late because the configuration callback needs to run first
  // before creating the http transport with the dsn
  late final HttpTransport _httpTransport =
      HttpTransport(_options, RateLimiter(_options));

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
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
  Future<Map<String, FeatureFlag>?> fetchFeatureFlags() async =>
      _httpTransport.fetchFeatureFlags();
}
