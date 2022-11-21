import 'dart:async';
import 'dart:developer';

import 'package:meta/meta.dart';
import 'package:http/http.dart';

import '../sentry.dart';
import '../sentry_private.dart';
import 'client_reports/client_report_recorder.dart';
import 'client_reports/noop_client_report_recorder.dart';
import 'sentry_exception_factory.dart';
import 'sentry_stack_trace_factory.dart';
import 'diagnostic_logger.dart';
import 'environment/environment_variables.dart';
import 'noop_client.dart';
import 'transport/noop_transport.dart';
import 'utils.dart';
import 'version.dart';

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
  /// The ClockProvider is expected to return UTC time.
  @internal
  ClockProvider clock = getUtcDateTime;

  int _maxBreadcrumbs = 100;

  /// This variable controls the total amount of breadcrumbs that should be captured Default is 100
  int get maxBreadcrumbs => _maxBreadcrumbs;

  set maxBreadcrumbs(int maxBreadcrumbs) {
    assert(maxBreadcrumbs >= 0);
    _maxBreadcrumbs = maxBreadcrumbs;
  }

  /// Initial value of 20 MiB according to
  /// https://develop.sentry.dev/sdk/features/#max-attachment-size
  int _maxAttachmentSize = 20 * 1024 * 1024;

  /// Maximum allowed file size of attachments, in bytes.
  /// Attachments above this size will be discarded
  ///
  /// Remarks: Regardless of this setting, attachments are also limited to 20mb
  /// (compressed) on Relay.
  int get maxAttachmentSize => _maxAttachmentSize;

  set maxAttachmentSize(int maxAttachmentSize) {
    assert(maxAttachmentSize > 0);
    _maxAttachmentSize = maxAttachmentSize;
  }

  /// Maximum number of spans that can be attached to single transaction.
  ///
  /// The is an experimental feature. Use at your own risk.
  int _maxSpans = 1000;

  /// Returns the maximum number of spans that can be attached to single transaction.
  ///
  /// The is an experimental feature. Use at your own risk.
  int get maxSpans => _maxSpans;

  /// Sets the maximum number of spans that can be attached to single transaction.
  ///
  /// The is an experimental feature. Use at your own risk.
  set maxSpans(int maxSpans) {
    assert(maxSpans > 0);
    _maxSpans = maxSpans;
  }

  // ignore: deprecated_member_use_from_same_package
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
    // ignore: deprecated_member_use_from_same_package
    if (_debug == true && logger == noOpLogger) {
      _logger = _debugLogger;
    }
    if (_debug == false && logger == _debugLogger) {
      // ignore: deprecated_member_use_from_same_package
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
  /// In a Flutter environment, this setting also toggles recording of `debugPrint` calls.
  /// `debugPrint` calls are only recorded in release builds, though.
  bool enablePrintBreadcrumbs = true;

  /// If [platformChecker] is provided, it is used get the environment.
  /// This is useful in tests. Should be an implementation of [PlatformChecker].
  PlatformChecker platformChecker = PlatformChecker();

  /// If [environmentVariables] is provided, it is used get the environment
  /// variables. This is useful in tests.
  EnvironmentVariables environmentVariables = EnvironmentVariables.instance();

  /// When enabled, the current isolate will be attached to the event.
  /// This only applies to Dart:io platforms and only the current isolate.
  /// The Dart runtime doesn't provide information about other active isolates.
  ///
  /// When running on web, this option has no effect at all.
  ///
  /// When running in the Flutter context, this enables attaching of threads
  /// for native events, if supported for the native platform.
  /// Currently, this is only supported on Android.
  bool attachThreads = false;

  /// Whether to send personal identifiable information along with events
  bool sendDefaultPii = false;

  /// Whether [SentryEvent] deduplication is enabled.
  /// Can be further configured with [maxDeduplicationItems].
  /// Shoud be set to true if
  /// [SentryHttpClient] is used to capture failed requests.
  bool enableDeduplication = true;

  int _maxDeduplicationItems = 5;

  /// Describes how many exceptions are kept to be checked for deduplication.
  /// This should be a small positiv integer in order to keep deduplication
  /// performant.
  /// Is only in effect if [enableDeduplication] is set to true.
  int get maxDeduplicationItems => _maxDeduplicationItems;

  set maxDeduplicationItems(int count) {
    assert(count > 0);
    _maxDeduplicationItems = count;
  }

  double? _tracesSampleRate;

  /// Returns the traces sample rate Default is null (disabled)
  double? get tracesSampleRate => _tracesSampleRate;

  set tracesSampleRate(double? tracesSampleRate) {
    assert(tracesSampleRate == null ||
        (tracesSampleRate >= 0 && tracesSampleRate <= 1));
    _tracesSampleRate = tracesSampleRate;
  }

  /// This function is called by [TracesSamplerCallback] to determine if transaction is sampled - meant
  /// to be sent to Sentry.
  TracesSamplerCallback? tracesSampler;

  /// Send statistics to sentry when the client drops events.
  bool sendClientReports = true;

  /// If enabled, [scopeObservers] will be called when mutating scope.
  bool enableScopeSync = true;

  final List<ScopeObserver> _scopeObservers = [];

  List<ScopeObserver> get scopeObservers => _scopeObservers;

  void addScopeObserver(ScopeObserver scopeObserver) {
    _scopeObservers.add(scopeObserver);
  }

  @internal
  late ClientReportRecorder recorder = NoOpClientReportRecorder();

  /// List of strings/regex controlling to which outgoing requests
  /// the SDK will attach tracing headers.
  ///
  /// By default the SDK will attach those headers to all outgoing
  /// requests. If this option is provided, the SDK will match the
  /// request URL of outgoing requests against the items in this
  /// array, and only attach tracing headers if a match was found.
  final List<String> tracePropagationTargets = ['.*'];

  /// The idle time to wait until the transaction will be finished.
  /// The transaction will use the end timestamp of the last finished span as
  /// the endtime for the transaction.
  ///
  /// When set to null the transaction must be finished manually.
  ///
  /// The default is 3 seconds.
  Duration? idleTimeout = Duration(seconds: 3);

  SentryOptions({this.dsn, PlatformChecker? checker}) {
    if (checker != null) {
      platformChecker = checker;
    }

    sdk = SdkVersion(name: sdkName(platformChecker.isWeb), version: sdkVersion);
    sdk.addPackage('pub:sentry', sdkVersion);
  }

  @internal
  SentryOptions.empty() {
    sdk = SdkVersion(name: 'noop', version: sdkVersion);
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

  /// Returns if tracing should be enabled. If tracing is disabled, starting transactions returns
  /// [NoOpSentrySpan].
  bool isTracingEnabled() {
    return tracesSampleRate != null || tracesSampler != null;
  }

  @internal
  late SentryExceptionFactory exceptionFactory = SentryExceptionFactory(this);

  @internal
  late SentryStackTraceFactory stackTraceFactory =
      SentryStackTraceFactory(this);

  @internal
  late SentryClientAttachmentProcessor clientAttachmentProcessor =
      SentryClientAttachmentProcessor();

  void _debugLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    log(
      '[${level.name}] $message',
      level: level.toDartLogLevel(),
      name: logger ?? 'sentry',
      time: clock(),
      error: exception,
      stackTrace: stackTrace,
    );
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
  String? logger,
  Object? exception,
  StackTrace? stackTrace,
});

typedef TracesSamplerCallback = double? Function(
    SentrySamplingContext samplingContext);

/// A NoOp logger that does nothing
@Deprecated('This will be made private or removed in the future')
void noOpLogger(
  SentryLevel level,
  String message, {
  String? logger,
  Object? exception,
  StackTrace? stackTrace,
}) {}

/// A Logger that prints out the level and message
@Deprecated('This will be made private or removed in the future')
void dartLogger(
  SentryLevel level,
  String message, {
  String? logger,
  Object? exception,
  StackTrace? stackTrace,
}) {
  log(
    '[${level.name}] $message',
    level: level.toDartLogLevel(),
    name: logger ?? 'sentry',
    time: getUtcDateTime(),
    error: exception,
    stackTrace: stackTrace,
  );
}
