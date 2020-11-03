import 'dart:async';

import 'hub.dart';
import 'hub_adapter.dart';
import 'noop_hub.dart';
import 'protocol.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';

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

    // let's set the default values to options
    if (!_setDefaultConfiguration(options)) {
      return;
    }

    final hub = currentHub;
    _hub = Hub(options);
    hub.close();

    // execute integrations after hub being enabled
    options.integrations.forEach((integration) {
      integration(HubAdapter(), options);
    });
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic hint,
  }) async =>
      currentHub.captureEvent(event, hint: hint);

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    dynamic hint,
  }) async =>
      currentHub.captureException(
        exception,
        stackTrace: stackTrace,
        hint: hint,
      );

  static Future<SentryId> captureMessage(
    String message, {
    SentryLevel level,
    String template,
    List<dynamic> params,
    dynamic hint,
  }) async =>
      currentHub.captureMessage(
        message,
        level: level,
        template: template,
        params: params,
        hint: hint,
      );

  /// Close the client SDK
  static void close() {
    final hub = currentHub;
    _hub = NoOpHub();
    return hub.close();
  }

  /// Check if the current Hub is enabled/active.
  static bool get isEnabled => currentHub.isEnabled;

  /// Last event id recorded by the current Hub
  static SentryId get lastEventId => currentHub.lastEventId;

  /// Adds a breacrumb to the current Scope
  static void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) =>
      currentHub.addBreadcrumb(crumb, hint: hint);

  /// Configures the scope through the callback.
  static void configureScope(ScopeCallback callback) =>
      currentHub.configureScope(callback);

  /// Clones the current Hub
  static Hub clone() => currentHub.clone();

  /// Binds a different client to the current hub
  static void bindClient(SentryClient client) => currentHub.bindClient(client);

  static bool _setDefaultConfiguration(SentryOptions options) {
    // if DSN is null, let's crash the App.
    if (options.dsn == null) {
      throw ArgumentError.notNull(
          'DSN is required. Use empty string to disable SDK.');
    }
    // if the DSN is empty, let's disable the SDK
    if (options.dsn.isEmpty) {
      close();
      return false;
    }

    // try parsing the dsn
    Dsn.parse(options.dsn);

    // if logger os NoOp, let's set a logger that prints on the console
    if (options.debug && options.logger == noOpLogger) {
      options.logger = dartLogger;
    }
    return true;
  }
}
