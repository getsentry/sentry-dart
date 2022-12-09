import 'dart:async';

import 'package:meta/meta.dart';

import 'default_integrations.dart';
import 'event_processor/enricher/enricher_event_processor.dart';
import 'environment/environment_variables.dart';
import 'event_processor/deduplication_event_processor.dart';
import 'event_processor/exception/exception_event_processor.dart';
import 'hub.dart';
import 'hub_adapter.dart';
import 'integration.dart';
import 'noop_hub.dart';
import 'noop_isolate_error_integration.dart'
    if (dart.library.io) 'isolate_error_integration.dart';
import 'protocol.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';
import 'sentry_user_feedback.dart';
import 'tracing.dart';

/// Configuration options callback
typedef OptionsConfiguration = FutureOr<void> Function(SentryOptions);

/// Runs a callback inside of the `runZonedGuarded` method, useful for running your `runApp(MyApp())`
typedef AppRunner = FutureOr<void> Function();

/// Sentry SDK main entry point
class Sentry {
  static Hub _hub = NoOpHub();

  Sentry._();

  /// Initializes the SDK
  /// passing a [AppRunner] callback allows to run the app within its own error
  /// zone ([`runZonedGuarded`](https://api.dart.dev/stable/2.10.4/dart-async/runZonedGuarded.html))
  static Future<void> init(
    OptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    @internal bool callAppRunnerInRunZonedGuarded = true,
    @internal SentryOptions? options,
  }) async {
    final sentryOptions = options ?? SentryOptions();
    await _initDefaultValues(sentryOptions);

    try {
      await optionsConfiguration(sentryOptions);
    } catch (exception, stackTrace) {
      sentryOptions.logger(
        SentryLevel.error,
        'Error in options configuration.',
        exception: exception,
        stackTrace: stackTrace,
      );
    }

    if (sentryOptions.dsn == null) {
      throw ArgumentError('DSN is required.');
    }

    await _init(sentryOptions, appRunner, callAppRunnerInRunZonedGuarded);
  }

  static Future<void> _initDefaultValues(SentryOptions options) async {
    _setEnvironmentVariables(options);

    // Throws when running on the browser
    if (!options.platformChecker.isWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegrationByIndex(0, IsolateErrorIntegration());
    }

    options.addEventProcessor(EnricherEventProcessor(options));
    options.addEventProcessor(ExceptionEventProcessor(options));
    options.addEventProcessor(DeduplicationEventProcessor(options));
  }

  /// This method reads available environment variables and uses them
  /// accordingly.
  /// To see which environment variables are available, see [EnvironmentVariables]
  ///
  /// The precedence of these options are also described on
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
  static Future<void> _init(
    SentryOptions options,
    AppRunner? appRunner,
    bool callAppRunnerInRunZonedGuarded,
  ) async {
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
      if (callAppRunnerInRunZonedGuarded) {
        var runIntegrationsAndAppRunner = () async {
          final integrations = options.integrations
              .where((i) => i is! RunZonedGuardedIntegration);
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
        await appRunner();
      }
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
    ScopeCallback? withScope,
  }) =>
      _hub.captureEvent(
        event,
        stackTrace: stackTrace,
        hint: hint,
        withScope: withScope,
      );

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      _hub.captureException(
        throwable,
        stackTrace: stackTrace,
        hint: hint,
        withScope: withScope,
      );

  /// Reports a [message] to Sentry.io.
  static Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List<dynamic>? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      _hub.captureMessage(
        message,
        level: level,
        template: template,
        params: params,
        hint: hint,
        withScope: withScope,
      );

  /// Reports a [userFeedback] to Sentry.io.
  ///
  /// First capture an event and use the [SentryId] to create a [SentryUserFeedback]
  static Future<void> captureUserFeedback(SentryUserFeedback userFeedback) =>
      _hub.captureUserFeedback(userFeedback);

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
  static Future<void> addBreadcrumb(Breadcrumb crumb, {dynamic hint}) async =>
      await _hub.addBreadcrumb(crumb, hint: hint);

  /// Configures the scope through the callback.
  static FutureOr<void> configureScope(ScopeCallback callback) async =>
      await _hub.configureScope(callback);

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

    return true;
  }

  /// Creates a Transaction and returns the instance.
  static ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      _hub.startTransaction(
        name,
        operation,
        description: description,
        startTimestamp: startTimestamp,
        bindToScope: bindToScope,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd,
        onFinish: onFinish,
        customSamplingContext: customSamplingContext,
      );

  /// Creates a Transaction and returns the instance.
  static ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
  }) =>
      _hub.startTransactionWithContext(
        transactionContext,
        customSamplingContext: customSamplingContext,
        startTimestamp: startTimestamp,
        bindToScope: bindToScope,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd,
        onFinish: onFinish,
      );

  /// Gets the current active transaction or span bound to the scope.
  static ISentrySpan? getSpan() => _hub.getSpan();

  @internal
  static Hub get currentHub => _hub;
}
