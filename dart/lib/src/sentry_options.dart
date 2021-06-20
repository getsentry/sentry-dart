import 'dart:async';
import 'dart:developer';

import 'package:http/http.dart';

import 'diagnostic_logger.dart';
import 'environment_variables.dart';
import 'event_processor.dart';
import 'integration.dart';
import 'noop_client.dart';
import 'protocol.dart';
import 'transport/noop_transport.dart';
import 'transport/transport.dart';
import 'utils.dart';
import 'version.dart';
import 'platform_checker.dart';

// TODO: Scope observers, enableScopeSync
// TODO: shutdownTimeout, flushTimeoutMillis
// https://api.dart.dev/stable/2.10.2/dart-io/HttpClient/close.html doesn't have a timeout param, we'd need to implement manually

/// Sentry SDK options
class SentryOptions {
  /// Default Log level if not specified Default is DEBUG
  static final SentryLevel _defaultDiagnosticLevel = SentryLevel.debug;

  /// The DSN tells the SDK where to send the events to. If an empty string is
  /// used, the SDK will not send any events.
  String? dsn;

  /// If [compressPayload] is `true` the outgoing HTTP payloads are compressed
  /// using gzip. Otherwise, the payloads are sent in plain UTF8-encoded JSON
  /// text. The compression is enabled by default.
  bool compressPayload = true;

  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  /// If you don't need to send events, use [NoOpClient].
  Client httpClient = NoOpClient();

  /// If [clock] is provided, it is used to get time instead of the system
  /// clock. This is useful in tests. Should be an implementation of [ClockProvider].
  ClockProvider clock = getUtcDateTime;

  int _maxBreadcrumbs = 100;

  /// This variable controls the total amount of breadcrumbs that should be captured Default is 100
  int get maxBreadcrumbs => _maxBreadcrumbs;

  set maxBreadcrumbs(int maxBreadcrumbs) {
    assert(maxBreadcrumbs >= 0);
    _maxBreadcrumbs = maxBreadcrumbs;
  }

  SentryLogger _logger = noOpLogger;

  /// Logger interface to log useful debugging information if debug is enabled
  SentryLogger get logger => _logger;

  set logger(SentryLogger logger) {
    _logger = DiagnosticLogger(logger, this).log;
  }

  final List<EventProcessor> _eventProcessors = [];

  /// Are callbacks that run for every event. They can either return a new event which in most cases
  /// means just adding data OR return null in case the event will be dropped and not sent.
  ///
  /// Global Event processors are executed after the Scope's processors
  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  final List<Integration> _integrations = [];

  /// Code that provides middlewares, bindings or hooks into certain frameworks or environments,
  /// along with code that inserts those bindings and activates them.
  List<Integration> get integrations => List.unmodifiable(_integrations);

  /// Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
  /// information if something goes wrong. Default is disabled.
  bool get debug => _debug;

  set debug(bool newValue) {
    _debug = newValue;
    if (_debug == true && logger == noOpLogger) {
      _logger = dartLogger;
    }
    if (_debug == false && logger == dartLogger) {
      _logger = noOpLogger;
    }
  }

  bool _debug = false;

  /// minimum LogLevel to be used if debug is enabled
  SentryLevel diagnosticLevel = _defaultDiagnosticLevel;

  /// Sentry client name used for the HTTP authHeader and userAgent eg
  /// sentry.{language}.{platform}/{version} eg sentry.java.android/2.0.0 would be a valid case
  String? sentryClientName;

  /// This function is called with an SDK specific event object and can return a modified event
  /// object or nothing to skip reporting the event
  BeforeSendCallback? beforeSend;

  /// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
  /// to the scope. When nothing is returned from the function, the breadcrumb is dropped
  BeforeBreadcrumbCallback? beforeBreadcrumb;

  /// Sets the release. SDK will try to automatically configure a release out of the box
  /// See [docs for further information](https://docs.sentry.io/platforms/flutter/configuration/releases/)
  String? release;

  /// Sets the environment. This string is freeform and not set by default. A release can be
  /// associated with more than one environment to separate them in the UI Think staging vs prod or
  /// similar.
  /// See [docs for further information](https://docs.sentry.io/platforms/flutter/configuration/environments/)
  String? environment;

  /// Configures the sample rate as a percentage of events to be sent in the range of 0.0 to 1.0. if
  /// 1.0 is set it means that 100% of events are sent. If set to 0.1 only 10% of events will be
  /// sent. Events are picked randomly. Default is null (disabled)
  double? sampleRate;

  final List<String> _inAppExcludes = [];

  /// A list of string prefixes of packages names that do not belong to the app, but rather third-party
  /// packages. Packages considered not to be part of the app will be hidden from stack traces by
  /// default.
  /// example : ['sentry'] will exclude exception from 'package:sentry/sentry.dart'
  List<String> get inAppExcludes => List.unmodifiable(_inAppExcludes);

  final List<String> _inAppIncludes = [];

  /// A list of string prefixes of packages names that belong to the app. This option takes precedence
  /// over inAppExcludes.
  /// example : ['sentry'] will include exception from 'package:sentry/sentry.dart'
  List<String> get inAppIncludes => List.unmodifiable(_inAppIncludes);

  /// Configures whether stack trace frames are considered in app frames by default.
  /// You can use this to essentially make [inAppIncludes] or [inAppExcludes]
  /// an allow or deny list.
  /// This value is only used if Sentry can not find the origin of the frame.
  ///
  /// - If [considerInAppFramesByDefault] is true you only need to maintain
  /// [inAppExcludes].
  /// - If [considerInAppFramesByDefault] is false you only need to maintain
  /// [inAppIncludes].
  bool considerInAppFramesByDefault = true;

  /// The transport is an internal construct of the client that abstracts away the event sending.
  Transport transport = NoOpTransport();

  /// Sets the distribution. Think about it together with release and environment
  String? dist;

  /// The server name used in the Sentry messages.
  String? serverName;

  /// Sdk object that contains the Sentry Client Name and its version
  late SdkVersion sdk;

  /// When enabled, stack traces are automatically attached to all messages logged.
  /// Stack traces are always attached to exceptions;
  /// however, when this option is set, stack traces are also sent with messages.
  /// This option, for instance, means that stack traces appear next to all log messages.
  ///
  /// This option is `true` by default.
  ///
  /// Grouping in Sentry is different for events with stack traces and without.
  /// As a result, you will get new groups as you enable or disable this flag for certain events.
  bool attachStacktrace = true;

  /// Enable this option if you want to record calls to `print()` as
  /// breadcrumbs.
  bool enablePrintBreadcrumbs = true;

  /// If [platformChecker] is provided, it is used get the envirnoment.
  /// This is useful in tests. Should be an implementation of [PlatformChecker].
  PlatformChecker platformChecker = PlatformChecker();

  /// If [environmentVariables] is provided, it is used get the envirnoment
  /// variables. This is useful in tests.
  EnvironmentVariables environmentVariables = EnvironmentVariables();

  /// When enabled, all the threads are automatically attached to all logged events (Android).
  bool attachThreads = false;

  /// Whether to send personal identifiable information along with events
  bool sendDefaultPii = false;

  SentryOptions({this.dsn, PlatformChecker? checker}) {
    if (checker != null) {
      platformChecker = checker;
    }

    // In debug mode we want to log everything by default to the console.
    // In order to do that, this must be the first thing the SDK does
    // and the first thing the SDK does, is to instantiate SentryOptions
    if (platformChecker.isDebugMode()) {
      debug = true;
    }

    sdk = SdkVersion(name: sdkName(platformChecker.isWeb), version: sdkVersion);
    sdk.addPackage('pub:sentry', sdkVersion);
  }

  /// Adds an event processor
  void addEventProcessor(EventProcessor eventProcessor) {
    _eventProcessors.add(eventProcessor);
  }

  /// Removes an event processor
  void removeEventProcessor(EventProcessor eventProcessor) {
    _eventProcessors.remove(eventProcessor);
  }

  /// Adds an integration
  void addIntegration(Integration integration) {
    _integrations.add(integration);
  }

  /// Adds an integration in the given index
  void addIntegrationByIndex(int index, Integration integration) {
    _integrations.insert(index, integration);
  }

  /// Removes an integration
  void removeIntegration(Integration integration) {
    _integrations.remove(integration);
  }

  /// Adds an inAppExclude
  void addInAppExclude(String inApp) {
    _inAppExcludes.add(inApp);
  }

  /// Adds an inAppIncludes
  void addInAppInclude(String inApp) {
    _inAppIncludes.add(inApp);
  }
}

/// This function is called with an SDK specific event object and can return a modified event
/// object or nothing to skip reporting the event
typedef BeforeSendCallback = FutureOr<SentryEvent?> Function(
  SentryEvent event, {
  dynamic hint,
});

/// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
/// to the scope. When nothing is returned from the function, the breadcrumb is dropped
typedef BeforeBreadcrumbCallback = Breadcrumb? Function(
  Breadcrumb? breadcrumb, {
  dynamic hint,
});

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

/// Logger interface to log useful debugging information if debug is enabled
typedef SentryLogger = void Function(
  SentryLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// A NoOp logger that does nothing
void noOpLogger(
  SentryLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {}

/// A Logger that prints out the level and message
void dartLogger(
  SentryLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  log(
    '[${level.name}] $message',
    level: level.toDartLogLevel(),
    name: 'sentry',
    time: getUtcDateTime(),
    error: error,
    stackTrace: stackTrace,
  );
}
