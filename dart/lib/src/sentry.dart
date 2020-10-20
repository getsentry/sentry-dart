import 'dart:async';

import 'package:meta/meta.dart';

import 'client.dart';
import 'hub.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'noop_hub.dart';

/// Configuration options callback
typedef OptionsConfiguration = void Function(SentryOptions);

/// Sentry SDK main entry point
///
class Sentry {
  static Hub _hub = NoOpHub();

  Sentry._();

  /// Returns the current hub
  static Hub get currentHub => _hub;

  /// Initializes the SDK
  static void init(OptionsConfiguration optionsConfiguration) {
    final options = SentryOptions();
    optionsConfiguration(options);
    _init(options);
  }

  /// Initializes the SDK
  static void _init(SentryOptions options) {
    if (isEnabled) {
      options.logger(
        SentryLevel.warning,
        'Sentry has been already initialized. Previous configuration will be overwritten.',
      );
    }

    _setDefaultConfiguration(options);

    final hub = currentHub;
    _hub = Hub(options);
    hub.close();
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(Event event) async {
    return currentHub.captureEvent(event);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic error, {
    dynamic stackTrace,
  }) async {
    return currentHub.captureException(error, stackTrace: stackTrace);
  }

  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level,
    String template,
    List<dynamic> params,
  }) async {
    return currentHub.captureMessage(
      message,
      level: level,
      template: template,
      params: params,
    );
  }

  /// Close the client SDK
  static Future<void> close() async => currentHub.close();

  /// Check if the current Hub is enabled/active.
  static bool get isEnabled => currentHub.isEnabled;

  static void _setDefaultConfiguration(SentryOptions options) {
    // TODO: check DSN nullability and empty

    if (options.debug && options.logger == noOpLogger) {
      options.logger = dartLogger;
    }
  }

  /// client injector only use for testing
  @visibleForTesting
  static void initClient(SentryClient client) => currentHub.bindClient(client);
}
