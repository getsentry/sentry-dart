import 'dart:async';

import 'default_integrations.dart';
import 'environment_variables.dart';
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
  @Deprecated(
    'This is scheduled to be removed in Sentry v6.0.0. '
    'Instead of currentHub you should use Sentry\'s static methods.',
  )
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
    SentryOptions options,
    AppRunner? appRunner,
  ) async {
    options.debug = options.platformChecker.isDebugMode();

    _setEnvironmentVariables(options);

    // Throws when running on the browser
    if (!isWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegrationByIndex(0, IsolateErrorIntegration());
    }
  }

  /// This method reads available environment variables and uses them
  /// accordingly.
  /// To see which environment variables are available, see [EnvironmentVariables]
  ///
  /// The precendence of these options are also described on
  /// https://docs.sentry.io/platforms/dart/configuration/options/
  static void _setEnvironmentVariables(SentryOptions options) {
    final vars = options.environmentVariables;
    options.dsn = options.dsn ?? vars.dsn;

    if (options.environment == null) {
      var environment = vars.environmentForMode(options.platformChecker);
      options.environment = vars.environment ?? environment;
    }

    options.release = options.release ?? vars.release;
    options.dist = options.dist ?? vars.dist;
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
    if (await _setDefaultConfiguration(options)) {
      final hub = _hub;
      _hub = Hub(options);
      await hub.close();
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
      _hub.captureEvent(event, stackTrace: stackTrace, hint: hint);

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
  }) async =>
      _hub.captureException(
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
      _hub.captureMessage(
        message,
        level: level,
        template: template,
        params: params,
        hint: hint,
      );

  /// Close the client SDK
  static Future<void> close() async {
    final hub = _hub;
    _hub = NoOpHub();
    await hub.close();
  }

  /// Check if the current Hub is enabled/active.
  static bool get isEnabled => _hub.isEnabled;

  /// Last event id recorded by the current Hub
  static SentryId get lastEventId => _hub.lastEventId;

  /// Adds a breacrumb to the current Scope
  static void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) =>
      _hub.addBreadcrumb(crumb, hint: hint);

  /// Configures the scope through the callback.
  static void configureScope(ScopeCallback callback) =>
      _hub.configureScope(callback);

  /// Clones the current Hub
  static Hub clone() => _hub.clone();

  /// Binds a different client to the current hub
  static void bindClient(SentryClient client) => _hub.bindClient(client);

  static Future<bool> _setDefaultConfiguration(SentryOptions options) async {
    // if the DSN is empty, let's disable the SDK
    if (options.dsn?.isEmpty ?? false) {
      await close();
      return false;
    }

    // try parsing the dsn
    Dsn.parse(options.dsn!);

    // If the user set debug to false and the default logger is still
    // `dartLogger` we set the logger to `noOpLogger`.
    // `dartLogger` is the default because otherwise the logs won't be to the
    // user visible between Sentry's initialization and the invocation of the
    // options configuration callback.
    if (options.debug == false && options.logger == dartLogger) {
      options.logger = noOpLogger;
    }

    return true;
  }
}
