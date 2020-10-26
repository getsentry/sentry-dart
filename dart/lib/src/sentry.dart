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

    // if there's an empty DSN, SDK is disabled
    if (!_setDefaultConfiguration(options)) {
      return;
    }

    final hub = currentHub;
    _hub = Hub(options);
    hub.close();
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic hint,
  }) async {
    return currentHub.captureEvent(event, hint: hint);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic error, {
    dynamic stackTrace,
    dynamic hint,
  }) async {
    return currentHub.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint,
    );
  }

  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level,
    String template,
    List<dynamic> params,
    dynamic hint,
  }) async {
    return currentHub.captureMessage(
      message,
      level: level,
      template: template,
      params: params,
      hint: hint,
    );
  }

  /// Close the client SDK
  static void close() {
    final hub = currentHub;
    _hub = NoOpHub();
    return hub.close();
  }

  /// Check if the current Hub is enabled/active.
  static bool get isEnabled => currentHub.isEnabled;

  /// Adds a breacrumb to the current Scope
  static void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    currentHub.addBreadcrumb(crumb, hint: hint);
  }

  static bool _setDefaultConfiguration(SentryOptions options) {
    if (options.dsn == null) {
      throw ArgumentError.notNull(
          'DSN is required. Use empty string to disable SDK.');
    }
    if (options.dsn.isEmpty) {
      close();
      return false;
    }

    if (options.debug && options.logger == noOpLogger) {
      options.logger = dartLogger;
    }
    return true;
  }

  /// client injector only use for testing
  @visibleForTesting
  static void initClient(SentryClient client) => currentHub.bindClient(client);
}
