import 'dart:async';

import 'package:meta/meta.dart';

import 'client.dart';
import 'hub.dart';
import 'protocol.dart';
import 'sentry_options.dart';

/// Configuration options callback
typedef OptionsConfiguration = void Function(SentryOptions);

/// Sentry SDK main entry point
///
class Sentry {
  static Hub _hub;

  Sentry._();

  static void init(OptionsConfiguration optionsConfiguration) {
    final options = SentryOptions();
    optionsConfiguration(options);
    _setDefaultConfiguration(options);
    _hub = Hub(options);
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(Event event) async {
    return _hub.captureEvent(event);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic error, {
    dynamic stackTrace,
  }) async {
    return _hub.captureException(error, stackTrace: stackTrace);
  }

  /// Close the client SDK
  static Future<void> close() async => _hub.close();

  static void _setDefaultConfiguration(SentryOptions options) {
    // TODO: check DSN nullability and empty

    if (options.debug && options.logger == noOpLogger) {
      options.logger = dartLogger;
    }
  }

  /// client injector only use for testing
  @visibleForTesting
  static void initClient(SentryClient client) => _hub.bindClient(client);
}
