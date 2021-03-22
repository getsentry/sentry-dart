import 'dart:async';

import 'package:sentry/src/environment_variables.dart';

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
import 'integration.dart';

/// Configuration options callback
typedef OptionsConfiguration = FutureOr<void> Function(SentryOptions);

/// Runs a callback inside of the `runZonedGuarded` method, useful for running your `runApp(MyApp())`
typedef AppRunner = FutureOr<void> Function();

/// Sentry SDK main entry point
class Sentry {
  static Hub _hub = NoOpHub();

  Sentry._();

  /// Returns the current hub
  static Hub get currentHub => _hub;

  /// Initializes the SDK
  /// passing a [AppRunner] callback allows to run the app within its own error
  /// zone ([`runZonedGuarded`](https://api.dart.dev/stable/2.10.4/dart-async/runZonedGuarded.html))
  ///
  /// You should use [optionsConfiguration] instead of passing [sentryOptions]
  /// yourself. [sentryOptions] is mainly intendet for use by other Sentry clients
  /// such as SentryFlutter.
  static Future<void> init(
    OptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    SentryOptions? options,
  }) async {
    final sentryOptions = options ?? SentryOptions();
    await _initDefaultValues(sentryOptions, appRunner);

    await optionsConfiguration(sentryOptions);

    if (sentryOptions.dsn == null) {
      throw ArgumentError('DSN is required.');
    }

    await _init(sentryOptions, appRunner);
  }

  static Future<void> _initDefaultValues(
      SentryOptions options, AppRunner? appRunner) async {
    var environment = options.platformChecker.environment;
    options.environment = options.environment ?? environment;

    setEnvironmentVariables(options, EnvironmentVariables());

    // Throws when running on the browser
    if (!isWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegrationByIndex(0, IsolateErrorIntegration());
    }
  }

  /// Initializes the SDK
  static Future<void> _init(SentryOptions options, AppRunner? appRunner) async {
    if (isEnabled) {
      options.logger(
        SentryLevel.warning,
        'Sentry has been already initialized. Previous configuration will be overwritten.',
      );
    }

    // let's set the default values to options
    if (_setDefaultConfiguration(options)) {
      final hub = currentHub;
      _hub = Hub(options);
      hub.close();
    }

    // execute integrations after hub being enabled
    if (appRunner != null) {
      var runIntegrationsAndAppRunner = () async {
        final integrations = options.integrations
            .where((i) => !(i is RunZonedGuardedIntegration));
        await _callIntegrations(integrations, options);
        await appRunner();
      };

      final runZonedGuardedIntegration =
          RunZonedGuardedIntegration(runIntegrationsAndAppRunner);
      options.addIntegrationByIndex(0, runZonedGuardedIntegration);

      // RunZonedGuardedIntegration will run other integrations and appRunner
      // runZonedGuarded so all exception caught in the error handler are
      // handled
      await runZonedGuardedIntegration(HubAdapter(), options);
    } else {
      await _callIntegrations(options.integrations, options);
    }
  }

  static Future<void> _callIntegrations(
      Iterable<Integration> integrations, SentryOptions options) async {
    for (final integration in integrations) {
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
    String? message, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List<dynamic>? params,
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
    // if the DSN is empty, let's disable the SDK
    if (options.dsn?.isEmpty ?? false) {
      close();
      return false;
    }

    // try parsing the dsn
    Dsn.parse(options.dsn!);

    // if logger os NoOp, let's set a logger that prints on the console
    if (options.debug && options.logger == noOpLogger) {
      options.logger = dartLogger;
    }
    return true;
  }
}
