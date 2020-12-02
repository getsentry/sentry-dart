import 'dart:async';

import 'default_integrations.dart';
import 'hub.dart';
import 'hub_adapter.dart';
import 'noop_isolate_error_integration.dart'
    if (dart.library.io) 'isolate_error_integration.dart';
import 'noop_hub.dart';
import 'protocol.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';
import 'utils.dart';

/// Configuration options callback
typedef OptionsConfiguration = FutureOr<void> Function(SentryOptions);
// typedef OptionsConfiguration = FutureOr<void> Function<T extends SentryOptions>(
//     T);

/// Runs a callback inside of the `runZonedGuarded` method, useful for running your `runApp(MyApp())`
typedef AppRunner = FutureOr<void> Function();

/// Sentry SDK main entry point
class Sentry {
  static Hub _hub = NoOpHub();

  Sentry._();

  /// Returns the current hub
  static Hub get currentHub => _hub;

  /// Initializes the SDK
  /// passing a [AppRunner] callback allows to run the app within its own error zone (`runZonedGuarded`)
  /// https://api.dart.dev/stable/2.10.4/dart-async/runZonedGuarded.html
  static Future<void> init(
    OptionsConfiguration optionsConfiguration, {
    AppRunner appRunner,
    SentryOptions options,
  }) async {
    if (optionsConfiguration == null) {
      throw ArgumentError('OptionsConfiguration is required.');
    }

    final sentryOptions = options ?? SentryOptions();
    await _initDefaultValues(sentryOptions, appRunner);

    await optionsConfiguration(sentryOptions);

    if (sentryOptions == null) {
      throw ArgumentError('SentryOptions is required.');
    }

    await _init(sentryOptions);
  }

  static Future<void> _initDefaultValues(
    SentryOptions options,
    AppRunner appRunner,
  ) async {
    // if no environment is set, we set 'production' by default, but if we know it's
    // a non-release build, or the SENTRY_ENVIRONMENT is set, we read from it.
    if (const bool.hasEnvironment('SENTRY_ENVIRONMENT') || !isReleaseMode) {
      options.environment = const String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: 'debug',
      );
    }

    // if the SENTRY_DSN is set, we read from it.
    options.dsn = const bool.hasEnvironment('SENTRY_DSN')
        ? const String.fromEnvironment('SENTRY_DSN')
        : options.dsn;

    // Throws when running on the browser
    if (!isWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegrationByIndex(0, IsolateErrorIntegration());
    }

    // finally the runZonedGuarded, catch any errors in Dart code running
    // ‘outside’ the Flutter framework
    if (appRunner != null) {
      options.addIntegration(RunZonedGuardedIntegration(appRunner));
    }
  }

  /// Initializes the SDK
  static Future<void> _init(SentryOptions options) async {
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
    for (final integration in options.integrations) {
      await integration(HubAdapter(), options);
    }
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
  }) async =>
      currentHub.captureEvent(event, stackTrace: stackTrace, hint: hint);

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
  }) async =>
      currentHub.captureException(
        throwable,
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
    hub.close();
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
      throw ArgumentError(
        'DSN is required. Use empty string to disable SDK.',
      );
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
