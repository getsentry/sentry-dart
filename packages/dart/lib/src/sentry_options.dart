import 'dart:async';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../sentry.dart';
import 'client_reports/client_report_recorder.dart';
import 'client_reports/noop_client_report_recorder.dart';
import 'diagnostic_log.dart';
import 'environment/environment_variables.dart';
import 'noop_client.dart';
import 'platform/platform.dart';
import 'sentry_exception_factory.dart';
import 'sentry_stack_trace_factory.dart';
import 'transport/noop_transport.dart';
import 'version.dart';
import 'sentry_log_batcher.dart';
import 'noop_log_batcher.dart';
import 'dart:developer' as developer;

// TODO: shutdownTimeout, flushTimeoutMillis
// https://api.dart.dev/stable/2.10.2/dart-io/HttpClient/close.html doesn't have a timeout param, we'd need to implement manually

/// Sentry SDK options
class SentryOptions {
  /// Default Log level if not specified Default is WARNING
  static final SentryLevel _defaultDiagnosticLevel = SentryLevel.warning;

  String? _dsn;
  Dsn? _parsedDsn;

  /// The DSN tells the SDK where to send the events to.
  /// If an empty string is used, the SDK will not send any events.
  String? get dsn => _dsn;

  set dsn(String? value) {
    if (_dsn != value) {
      _dsn = value;
      _parsedDsn = null; // Invalidate the cached parsed DSN
    }
  }

  /// Evaluates and parses the DSN.
  /// May throw an exception if the DSN is invalid.
  @internal
  Dsn get parsedDsn {
    _parsedDsn ??= _parseDsn();
    return _parsedDsn!;
  }

  Dsn _parseDsn() {
    if (_dsn == null || _dsn!.isEmpty) {
      throw StateError('DSN is null or empty');
    }
    return Dsn.parse(_dsn!);
  }

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
  int _maxSpans = 1000;

  /// Returns the maximum number of spans that can be attached to single transaction.
  int get maxSpans => _maxSpans;

  /// Sets the maximum number of spans that can be attached to single transaction.
  set maxSpans(int maxSpans) {
    assert(maxSpans > 0);
    _maxSpans = maxSpans;
  }

  int _maxQueueSize = 30;

  /// Returns the max number of events Sentry will send when calling capture
  /// methods in a tight loop. Default is 30.
  int get maxQueueSize => _maxQueueSize;

  /// Sets how many unawaited events can be sent by Sentry. (e.g. capturing
  /// events in a tight loop) at once. If you need to send more, please use the
  /// await keyword.
  set maxQueueSize(int count) {
    assert(count > 0);
    _maxQueueSize = count;
  }

  /// Configures up to which size request bodies should be included in events.
  /// This does not change whether an event is captured.
  MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never;

  SdkLogCallback _log = noOpLog;

  /// Log callback to log useful debugging information if debug is enabled
  SdkLogCallback get log => _log;

  @internal
  set log(SdkLogCallback value) {
    diagnosticLog = DiagnosticLog(value, this);
    _log = diagnosticLog!.log;
  }

  @visibleForTesting
  DiagnosticLog? diagnosticLog;

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
  /// information if something goes wrong. Default is enabled in debug mode, otherwise it is disabled.
  bool get debug => _debug;

  set debug(bool newValue) {
    _debug = newValue;
    SentryDebugLogger.configure(isEnabled: _debug, minLevel: diagnosticLevel);
    if (_debug == true &&
        (log == noOpLog || diagnosticLog?.logger == noOpLog)) {
      log = debugLog;
    }
    if (_debug == false &&
        (log == debugLog || diagnosticLog?.logger == debugLog)) {
      log = noOpLog;
    }
  }

  bool _debug = false;

  /// minimum LogLevel to be used if debug is enabled
  SentryLevel diagnosticLevel = _defaultDiagnosticLevel;

  /// Sentry client name used for the HTTP authHeader and userAgent eg
  /// sentry.{language}.{platform}/{version} eg sentry.java.android/2.0.0 would be a valid case
  String get sentryClientName => '${sdk.name}/${sdk.version}';

  /// This function is called with an SDK specific event object and can return a modified event
  /// object or nothing to skip reporting the event
  BeforeSendCallback? beforeSend;

  /// This function is called with an SDK specific transaction object and can return a modified
  /// transaction object or nothing to skip reporting the transaction
  BeforeSendTransactionCallback? beforeSendTransaction;

  /// This function is called with an SDK specific feedback event object and can return a modified
  /// feedback event object or nothing to skip reporting the feedback event
  BeforeSendCallback? beforeSendFeedback;

  /// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
  /// to the scope. When nothing is returned from the function, the breadcrumb is dropped
  BeforeBreadcrumbCallback? beforeBreadcrumb;

  /// This function is called right before a metric is about to be emitted.
  /// Can return true to emit the metric, or false to drop it.
  BeforeMetricCallback? beforeMetricCallback;

  /// This function is called right before a log is about to be sent.
  /// Can return a modified log or null to drop the log.
  BeforeSendLogCallback? beforeSendLog;

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

  /// The ignoreErrors tells the SDK which errors should be not sent to the sentry server.
  /// If an null or an empty list is used, the SDK will send all transactions.
  /// To use regex add the `^` and the `$` to the string.
  List<String> ignoreErrors = [];

  /// The ignoreTransactions tells the SDK which transactions should be not sent to the sentry server.
  /// If null or an empty list is used, the SDK will send all transactions.
  /// To use regex add the `^` and the `$` to the string.
  List<String> ignoreTransactions = [];

  final List<String> _inAppExcludes = [];

  /// A list of string prefixes of packages names that do not belong to the app, but rather third-party
  /// packages. Packages considered not to be part of the app will be hidden from stack traces by
  /// default.
  /// example : `['sentry']` will exclude exception from `package:sentry/sentry.dart`
  List<String> get inAppExcludes => List.unmodifiable(_inAppExcludes);

  final List<String> _inAppIncludes = [];

  /// A list of string prefixes of packages names that belong to the app. This option takes precedence
  /// over inAppExcludes.
  /// example: `['sentry']` will include exception from `package:sentry/sentry.dart`
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

  /// If [runtimeChecker] is provided, it is used get the environment.
  /// This is useful in tests. Should be an implementation of [RuntimeChecker].
  RuntimeChecker runtimeChecker = RuntimeChecker();

  /// Info on which platform the SDK runs.
  Platform platform = Platform();

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

  /// Configures whether to record exceptions for failed requests.
  /// Examples for captures exceptions are:
  /// - In an browser environment this can be requests which fail because of CORS.
  /// - In an mobile or desktop application this can be requests which failed
  ///   because the connection was interrupted.
  /// Use with [SentryHttpClient] or `sentry_dio` integration for this to work,
  /// or iOS native where it sets the value to `enableCaptureFailedRequests`.
  bool captureFailedRequests = true;

  /// Whether to records requests as breadcrumbs. This is on by default.
  /// It only has an effect when the SentryHttpClient or dio integration is in
  /// use, or iOS native where it sets the value to `enableNetworkBreadcrumbs`.
  bool recordHttpBreadcrumbs = true;

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

  double? _profilesSampleRate;

  @internal // Only exposed by SentryFlutterOptions at the moment.
  double? get profilesSampleRate => _profilesSampleRate;

  @internal // Only exposed by SentryFlutterOptions at the moment.
  set profilesSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _profilesSampleRate = value;
  }

  /// Send statistics to sentry when the client drops events.
  bool sendClientReports = true;

  /// If enabled, [scopeObservers] will be called when mutating scope.
  bool enableScopeSync = true;

  final List<ScopeObserver> _scopeObservers = [];

  List<ScopeObserver> get scopeObservers => _scopeObservers;

  void addScopeObserver(ScopeObserver scopeObserver) {
    _scopeObservers.add(scopeObserver);
  }

  final List<Type> _ignoredExceptionsForType = [];

  /// Ignored exception types.
  List<Type> get ignoredExceptionsForType => _ignoredExceptionsForType;

  /// Adds exception type to the list of ignored exceptions.
  void addExceptionFilterForType(Type exceptionType) {
    _ignoredExceptionsForType.add(exceptionType);
  }

  /// Check if [ignoredExceptionsForType] contains an exception.
  bool containsIgnoredExceptionForType(dynamic exception) {
    return exception != null &&
        _ignoredExceptionsForType.contains(exception.runtimeType);
  }

  /// Enables Dart symbolication for stack traces in Flutter for Android and Cocoa.
  ///
  /// If true, the SDK will attempt to symbolicate Dart stack traces when
  /// [Sentry.init] is used instead of `SentryFlutter.init`. This is useful
  /// when native debug images are not available.
  ///
  /// Automatically set to `false` when using `SentryFlutter.init` on a platform
  /// with a native integration (e.g. Android, iOS, ...).
  bool enableDartSymbolication = true;

  @internal
  late ClientReportRecorder recorder = NoOpClientReportRecorder();

  @internal
  late SdkLifecycleRegistry lifecycleRegistry = SdkLifecycleRegistry(this);

  /// List of strings/regex controlling to which outgoing requests
  /// the SDK will attach tracing headers.
  ///
  /// By default the SDK will attach those headers to all outgoing
  /// requests. If this option is provided, the SDK will match the
  /// request URL of outgoing requests against the items in this
  /// array, and only attach tracing headers if a match was found.
  final List<String> tracePropagationTargets = ['.*'];

  /// This option is used to enable the propagation of the
  /// W3C Trace Context HTTP header traceparent on outgoing HTTP requests.
  /// This is useful when the receiving services only support OTel/W3C propagation
  ///
  /// The default is `false`.
  bool propagateTraceparent = false;

  /// The idle time to wait until the transaction will be finished.
  /// The transaction will use the end timestamp of the last finished span as
  /// the endtime for the transaction.
  ///
  /// When set to null the transaction must be finished manually.
  ///
  /// The default is 3 seconds.
  Duration? idleTimeout = Duration(seconds: 3);

  final _causeExtractorsByType = <Type, ExceptionCauseExtractor>{};

  final _stackTraceExtractorsByType = <Type, ExceptionStackTraceExtractor>{};

  /// Returns a previously added [ExceptionCauseExtractor] by type
  ExceptionCauseExtractor? exceptionCauseExtractor(Type type) {
    return _causeExtractorsByType[type];
  }

  /// Adds [ExceptionCauseExtractor] in order to extract inner exceptions
  void addExceptionCauseExtractor(ExceptionCauseExtractor extractor) {
    _causeExtractorsByType[extractor.exceptionType] = extractor;
  }

  /// Returns a previously added [ExceptionStackTraceExtractor] by type
  ExceptionStackTraceExtractor? exceptionStackTraceExtractor(Type type) {
    return _stackTraceExtractorsByType[type];
  }

  /// Adds [ExceptionStackTraceExtractor] in order to extract inner exceptions
  void addExceptionStackTraceExtractor(ExceptionStackTraceExtractor extractor) {
    _stackTraceExtractorsByType[extractor.exceptionType] = extractor;
  }

  /// Only for internal use. Changed SDK behaviour when set to true:
  /// - Rethrow exceptions that occur in user provided closures
  @internal
  bool automatedTestMode = false;

  /// Errors that the SDK automatically collects, for example in
  /// [SentryIsolate], have `level` [SentryLevel.fatal] set per default.
  /// Settings this to `false` will set the `level` to [SentryLevel.error].
  bool markAutomaticallyCollectedErrorsAsFatal = true;

  /// Enables identification of exception types in obfuscated builds.
  /// When true, the SDK will attempt to identify common exception types
  /// to improve readability of obfuscated issue titles.
  ///
  /// If you already have events with obfuscated issue titles this will change grouping.
  ///
  /// Default: `true`
  bool enableExceptionTypeIdentification = true;

  final List<ExceptionTypeIdentifier> _exceptionTypeIdentifiers = [];

  List<ExceptionTypeIdentifier> get exceptionTypeIdentifiers =>
      List.unmodifiable(_exceptionTypeIdentifiers);

  void addExceptionTypeIdentifierByIndex(
      int index, ExceptionTypeIdentifier exceptionTypeIdentifier) {
    _exceptionTypeIdentifiers.insert(
        index, exceptionTypeIdentifier.withCache());
  }

  /// Adds an exception type identifier to the beginning of the list.
  /// This ensures it is processed first and takes precedence over existing identifiers.
  void prependExceptionTypeIdentifier(
      ExceptionTypeIdentifier exceptionTypeIdentifier) {
    addExceptionTypeIdentifierByIndex(0, exceptionTypeIdentifier);
  }

  /// The Spotlight configuration.
  /// Disabled by default.
  /// ```dart
  /// spotlight = Spotlight(enabled: true)
  /// ```
  Spotlight spotlight = Spotlight(enabled: false);

  /// Configure a proxy to use for SDK API calls.
  ///
  /// On io platforms without native SDKs (dart, linux, windows), this will use
  /// an 'IOClient' with inner 'HTTPClient' for http communication.
  /// A http proxy will be set in returned for 'HttpClient.findProxy' in the
  /// form 'PROXY your_host:your_port'.
  /// When setting 'user' and 'pass', the 'HttpClient.addProxyCredentials'
  /// method will be called with empty 'realm'.
  ///
  /// On Android & iOS, the proxy settings are handled by the native SDK.
  /// iOS only supports http proxies, while macOS also supports socks.
  SentryProxy? proxy;

  /// Whether to group exceptions hierarchically.
  ///
  /// If true, exceptions will be grouped hierarchically if possible.
  ///
  /// This is opt-in, as it can lead to existing exception beeing grouped as new ones.
  bool groupExceptions = false;

  /// Enable to capture and send logs to Sentry.
  ///
  /// Disabled by default.
  bool enableLogs = false;

  /// Enables adding the module in [SentryStackFrame.module].
  /// This option only has an effect in non-obfuscated builds.
  /// Enabling this option may change grouping.
  bool includeModuleInStackTrace = false;

  late final SentryLogger logger = SentryLogger(clock);

  @internal
  SentryLogBatcher logBatcher = NoopLogBatcher();

  SentryOptions({String? dsn, Platform? platform, RuntimeChecker? checker}) {
    this.dsn = dsn;
    if (platform != null) {
      this.platform = platform;
    }
    if (checker != null) {
      runtimeChecker = checker;
    }
    sdk = SdkVersion(name: sdkName(this.platform.isWeb), version: sdkVersion);
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
  void addInAppExclude(String inAppInclude) {
    _inAppExcludes.add(inAppInclude);
  }

  /// Adds an inAppIncludes
  void addInAppInclude(String inAppExclude) {
    _inAppIncludes.add(inAppExclude);
  }

  /// Returns if tracing should be enabled. If tracing is disabled, starting transactions returns
  /// [NoOpSentrySpan].
  bool isTracingEnabled() {
    return tracesSampleRate != null || tracesSampler != null;
  }

  List<PerformanceCollector> get performanceCollectors =>
      _performanceCollectors;
  final List<PerformanceCollector> _performanceCollectors = [];

  void addPerformanceCollector(PerformanceCollector collector) {
    _performanceCollectors.add(collector);
  }

  @internal
  late SentryExceptionFactory exceptionFactory = SentryExceptionFactory(this);

  @internal
  late SentryStackTraceFactory stackTraceFactory =
      SentryStackTraceFactory(this);

  @visibleForTesting
  void debugLog(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[${level.name}] $message',
      level: level.toDartLogLevel(),
      name: logger ?? 'sentry',
      time: clock(),
      error: exception,
      stackTrace: stackTrace,
    );
  }
}

@visibleForTesting
void noOpLog(
  SentryLevel level,
  String message, {
  String? logger,
  Object? exception,
  StackTrace? stackTrace,
}) {}

/// This function is called with an SDK specific event object and can return a modified event
/// object or nothing to skip reporting the event
typedef BeforeSendCallback = FutureOr<SentryEvent?> Function(
  SentryEvent event,
  Hint hint,
);

/// This function is called with an SDK specific transaction object and can return a modified transaction
/// object or nothing to skip reporting the transaction
typedef BeforeSendTransactionCallback = FutureOr<SentryTransaction?> Function(
  SentryTransaction transaction,
  Hint hint,
);

/// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
/// to the scope. When nothing is returned from the function, the breadcrumb is dropped
typedef BeforeBreadcrumbCallback = Breadcrumb? Function(
  Breadcrumb? breadcrumb,
  Hint hint,
);

/// This function is called right before a metric is about to be emitted.
/// Can return true to emit the metric, or false to drop it.
typedef BeforeMetricCallback = bool Function(
  String key, {
  Map<String, String>? tags,
});

/// This function is called right before a log is about to be sent.
/// Can return a modified log or null to drop the log.
typedef BeforeSendLogCallback = FutureOr<SentryLog?> Function(SentryLog log);

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

/// Logger callback to log useful debugging information if debug is enabled
typedef SdkLogCallback = void Function(
  SentryLevel level,
  String message, {
  String? logger,
  Object? exception,
  StackTrace? stackTrace,
});

typedef TracesSamplerCallback = double? Function(
    SentrySamplingContext samplingContext);
