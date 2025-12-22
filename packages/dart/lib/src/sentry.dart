import 'dart:async';

import 'package:meta/meta.dart';

import 'dart_exception_type_identifier.dart';
import 'debug_logger.dart';
import 'environment/environment_variables.dart';
import 'event_processor/deduplication_event_processor.dart';
import 'event_processor/enricher/enricher_event_processor.dart';
import 'event_processor/exception/exception_event_processor.dart';
import 'event_processor/exception/exception_group_event_processor.dart';
import 'hint.dart';
import 'hub.dart';
import 'hub_adapter.dart';
import 'integration.dart';
import 'load_dart_debug_images_integration.dart';
import 'noop_hub.dart';
import 'noop_isolate_error_integration.dart'
    if (dart.library.io) 'isolate_error_integration.dart';
import 'protocol.dart';
import 'protocol/sentry_feedback.dart';
import 'run_zoned_guarded_integration.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';
import 'sentry_run_zoned_guarded.dart';
import 'tracing.dart';
import 'transport/data_category.dart';
import 'transport/task_queue.dart';
import 'feature_flags_integration.dart';
import 'sentry_logger.dart';
import 'logs_enricher_integration.dart';

/// Configuration options callback
typedef OptionsConfiguration = FutureOr<void> Function(SentryOptions);

/// Runs a callback inside of the `runZonedGuarded` method, useful for running your `runApp(MyApp())`
typedef AppRunner = FutureOr<void> Function();

/// Sentry SDK main entry point
class Sentry {
  static Hub _hub = NoOpHub();
  static TaskQueue<SentryId> _taskQueue = NoOpTaskQueue();

  Sentry._();

  /// Initializes the SDK
  /// passing a [AppRunner] callback allows to run the app within its own error
  /// zone ([`runZonedGuarded`](https://api.dart.dev/stable/2.10.4/dart-async/runZonedGuarded.html))
  static Future<void> init(
    OptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    @internal bool callAppRunnerInRunZonedGuarded = true,
    @internal RunZonedGuardedOnError? runZonedGuardedOnError,
    @internal SentryOptions? options,
  }) async {
    final sentryOptions = options ?? SentryOptions();

    await _initDefaultValues(sentryOptions);

    try {
      final config = optionsConfiguration(sentryOptions);
      if (config is Future) {
        await config;
      }
      _taskQueue = DefaultTaskQueue<SentryId>(
        sentryOptions.maxQueueSize,
        sentryOptions.log,
        sentryOptions.recorder,
      );
    } catch (exception, stackTrace) {
      sentryOptions.log(
        SentryLevel.error,
        'Error in options configuration.',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (sentryOptions.automatedTestMode) {
        rethrow;
      }
    }

    if (sentryOptions.dsn == null) {
      throw ArgumentError('DSN is required.');
    }

    await _init(sentryOptions, appRunner, callAppRunnerInRunZonedGuarded,
        runZonedGuardedOnError);
  }

  static Future<void> _initDefaultValues(SentryOptions options) async {
    _setEnvironmentVariables(options);

    // Throws when running on the browser
    if (!options.platform.isWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegrationByIndex(0, IsolateErrorIntegration());
    }

    if (options.runtimeChecker.isDebugMode()) {
      options.debug = true;
      debugLogger.debug(
        'Debug mode is enabled: Application is running in a debug environment.',
        category: 'init',
      );
    }

    if (options.enableDartSymbolication) {
      options.addIntegration(LoadDartDebugImagesIntegration());
    }

    options.addIntegration(FeatureFlagsIntegration());
    options.addIntegration(LogsEnricherIntegration());

    options.addEventProcessor(EnricherEventProcessor(options));
    options.addEventProcessor(ExceptionEventProcessor(options));
    options.addEventProcessor(DeduplicationEventProcessor(options));

    options.prependExceptionTypeIdentifier(DartExceptionTypeIdentifier());

    // Added last to ensure all error events have correct parent/child relationships
    options.addEventProcessor(ExceptionGroupEventProcessor(options));
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
      var environment = vars.environmentForMode(options.runtimeChecker);
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
    RunZonedGuardedOnError? runZonedGuardedOnError,
  ) async {
    if (isEnabled) {
      debugLogger.warning(
        'Sentry has been already initialized. Previous configuration will be overwritten.',
        category: 'init',
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

        final runZonedGuardedIntegration = RunZonedGuardedIntegration(
            runIntegrationsAndAppRunner, runZonedGuardedOnError);
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
      final execute = integration(HubAdapter(), options);
      if (execute is Future) {
        await execute;
      }
    }
  }

  /// Reports an [event] to Sentry.io.
  static Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) =>
      _taskQueue.enqueue(
          () => _hub.captureEvent(
                event,
                stackTrace: stackTrace,
                hint: hint,
                withScope: withScope,
              ),
          SentryId.empty(),
          event.type != null
              ? DataCategory.fromItemType(event.type!)
              : DataCategory.unknown);

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Hint? hint,
    SentryMessage? message,
    ScopeCallback? withScope,
  }) =>
      _taskQueue.enqueue(
        () => _hub.captureException(
          throwable,
          stackTrace: stackTrace,
          hint: hint,
          message: message,
          withScope: withScope,
        ),
        SentryId.empty(),
        DataCategory.error,
      );

  /// Reports a [message] to Sentry.io.
  static Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List<dynamic>? params,
    Hint? hint,
    ScopeCallback? withScope,
  }) =>
      _taskQueue.enqueue(
        () => _hub.captureMessage(
          message,
          level: level,
          template: template,
          params: params,
          hint: hint,
          withScope: withScope,
        ),
        SentryId.empty(),
        DataCategory.unknown,
      );

  /// Reports [SentryFeedback] to Sentry.io.
  ///
  /// Use [withScope] to add [SentryAttachment] to the feedback.
  static Future<SentryId> captureFeedback(
    SentryFeedback feedback, {
    Hint? hint,
    ScopeCallback? withScope,
  }) =>
      _taskQueue.enqueue(
        () => _hub.captureFeedback(
          feedback,
          hint: hint,
          withScope: withScope,
        ),
        SentryId.empty(),
        DataCategory.unknown,
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

  /// Adds a breadcrumb to the current Scope
  static Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) =>
      _hub.addBreadcrumb(crumb, hint: hint);

  /// Adds attributes to the current [Scope].
  /// These attributes will be applied to logs.
  /// When the same attribute keys exist on the current log,
  /// it takes precedence over an attribute with the same key set on any scope.
  static void setAttributes(Map<String, SentryAttribute> attributes) {
    _hub.setAttributes(attributes);
  }

  /// Removes the attribute [key] from the scope.
  static void removeAttribute(String key) {
    _hub.removeAttribute(key);
  }

  /// Configures the scope through the callback.
  static FutureOr<void> configureScope(ScopeCallback callback) =>
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
    options.parsedDsn;

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
  /// Returns `null` if performance is disabled in the options.
  static ISentrySpan? getSpan() => _hub.getSpan();

  static Future<void> addFeatureFlag(String flag, dynamic result) async {
    if (result is! bool) {
      return;
    }

    final featureFlagsIntegration = currentHub.options.integrations
        .whereType<FeatureFlagsIntegration>()
        .firstOrNull;

    if (featureFlagsIntegration == null) {
      debugLogger.warning(
        '$FeatureFlagsIntegration not found. Make sure Sentry is initialized before accessing the addFeatureFlag API.',
        category: 'feature_flags',
      );
      return;
    }

    await featureFlagsIntegration.addFeatureFlag(flag, result);
  }

  @internal
  static Hub get currentHub => _hub;

  /// Creates a new error handling zone with Sentry integration using [runZonedGuarded].
  ///
  /// This method provides automatic error reporting and breadcrumb tracking while
  /// allowing you to define a custom error handling zone. It wraps Dart's native
  /// [runZonedGuarded] function with Sentry-specific functionality.
  ///
  /// This function automatically records calls to `print()` as Breadcrumbs and
  /// can be configured using [SentryOptions.enablePrintBreadcrumbs].
  ///
  /// ```dart
  /// Sentry.runZonedGuarded(() {
  ///   WidgetsBinding.ensureInitialized();
  ///
  ///   // Errors before init will not be handled by Sentry
  ///
  ///   SentryFlutter.init(
  ///     (options) {
  ///     ...
  ///     },
  ///     appRunner: () => runApp(MyApp()),
  ///   );
  /// } (error, stackTrace) {
  ///   // Automatically sends errors to Sentry, no need to do any
  ///   // captureException calls on your part.
  ///   // On top of that, you can do your own custom stuff in this callback.
  /// });
  /// ```
  static dynamic runZonedGuarded<R>(
    R Function() body,
    void Function(Object error, StackTrace stack)? onError, {
    Map<Object?, Object?>? zoneValues,
    ZoneSpecification? zoneSpecification,
  }) =>
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        _hub,
        body,
        onError,
        zoneValues: zoneValues,
        zoneSpecification: zoneSpecification,
      );

  static SentryLogger get logger => currentHub.options.logger;
}
