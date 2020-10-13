import 'dart:async';

import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'sentry_options.dart';

/// Sentry SDK main entry point
///
class Sentry {
  static SentryClient _client;

  Sentry._();

  static void init(OptionsConfiguration<SentryOptions> optionsConfiguration) {
    final options = SentryOptions();
    optionsConfiguration.configure(options);
    _client = SentryClient(
      dsn: options.dsn,
      environment: options.environment,
      compressPayload: options.compressPayload,
      httpClient: options.httpClient,
      clock: options.clock,
      uuidGenerator: options.uuidGenerator,
    );
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryResponse> captureEvent(Event event) async {
    return _client.captureEvent(event: event);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryResponse> captureException(
    dynamic error, {
    dynamic stackTrace,
  }) async {
    return _client.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  }

  /// Close the client SDK
  static Future<void> close() async => _client.close();

  /// client injector only use for testing
  @visibleForTesting
  static void initClient(SentryClient client) => _client = client;
}

/// Configuration options callback
abstract class OptionsConfiguration<T extends SentryOptions> {
  ///configure the options
  void configure(T options);
}
