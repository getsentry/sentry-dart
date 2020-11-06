import 'dart:async';

import 'package:http/http.dart';

import 'diagnostic_logger.dart';
import 'hub.dart';
import 'noop_client.dart';
import 'protocol.dart';
import 'transport/noop_transport.dart';
import 'transport/transport.dart';
import 'utils.dart';
import 'version.dart';

const defaultEnvironment = 'production';

/// Sentry SDK options
class SentryOptions {
  /// Default Log level if not specified Default is DEBUG
  static final SentryLevel _defaultDiagnosticLevel = SentryLevel.debug;

  /// The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
  ///  just not send any events.
  String dsn;

  bool _compressPayload = true;

  /// If [compressPayload] is `true` the outgoing HTTP payloads are compressed
  /// using gzip. Otherwise, the payloads are sent in plain UTF8-encoded JSON
  /// text. If not specified, the compression is enabled by default.
  bool get compressPayload => _compressPayload;

  set compressPayload(bool compressPayload) =>
      _compressPayload = compressPayload ?? _compressPayload;

  Client _httpClient = NoOpClient();

  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  Client get httpClient => _httpClient;

  set httpClient(Client httpClient) => _httpClient = httpClient ?? _httpClient;

  ClockProvider _clock = getUtcDateTime;

  /// If [clock] is provided, it is used to get time instead of the system
  /// clock. This is useful in tests. Should be an implementation of [ClockProvider].
  ClockProvider get clock => _clock;

  set clock(ClockProvider clock) => _clock = clock ?? _clock;

  int _maxBreadcrumbs = 100;

  /// This variable controls the total amount of breadcrumbs that should be captured Default is 100
  int get maxBreadcrumbs => _maxBreadcrumbs;

  set maxBreadcrumbs(int maxBreadcrumbs) {
    _maxBreadcrumbs = (maxBreadcrumbs != null && maxBreadcrumbs >= 0)
        ? maxBreadcrumbs
        : _maxBreadcrumbs;
  }

  Logger _logger = noOpLogger;

  /// Logger interface to log useful debugging information if debug is enabled
  Logger get logger => _logger;

  set logger(Logger logger) {
    _logger = logger != null ? DiagnosticLogger(logger, this).log : _logger;
  }

  final List<EventProcessor> _eventProcessors = [];

  /// Are callbacks that run for every event. They can either return a new event which in most cases
  /// means just adding data OR return null in case the event will be dropped and not sent.
  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  final List<Integration> _integrations = [];

  // TODO: shutdownTimeout, flushTimeoutMillis
  // https://api.dart.dev/stable/2.10.2/dart-io/HttpClient/close.html doesn't have a timeout param, we'd need to implement manually

  /// Code that provides middlewares, bindings or hooks into certain frameworks or environments,
  /// along with code that inserts those bindings and activates them.
  List<Integration> get integrations => List.unmodifiable(_integrations);

  bool _debug = false;

  /// Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
  /// information if something goes wrong. Default is disabled.
  bool get debug => _debug;

  set debug(bool debug) {
    _debug = debug ?? _debug;
  }

  SentryLevel _diagnosticLevel = _defaultDiagnosticLevel;

  set diagnosticLevel(SentryLevel level) {
    _diagnosticLevel = level ?? _diagnosticLevel;
  }

  /// minimum LogLevel to be used if debug is enabled
  SentryLevel get diagnosticLevel => _diagnosticLevel;

  /// Sentry client name used for the HTTP authHeader and userAgent eg
  /// sentry.{language}.{platform}/{version} eg sentry.java.android/2.0.0 would be a valid case
  String sentryClientName;

  /// This function is called with an SDK specific event object and can return a modified event
  /// object or nothing to skip reporting the event
  BeforeSendCallback beforeSend;

  /// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
  /// to the scope. When nothing is returned from the function, the breadcrumb is dropped
  BeforeBreadcrumbCallback beforeBreadcrumb;

  /// Sets the release. SDK will try to automatically configure a release out of the box
  String release;

  /// Sets the environment. This string is freeform and not set by default. A release can be
  /// associated with more than one environment to separate them in the UI Think staging vs prod or
  /// similar.
  String environment;

  /// Configures the sample rate as a percentage of events to be sent in the range of 0.0 to 1.0. if
  /// 1.0 is set it means that 100% of events are sent. If set to 0.1 only 10% of events will be
  /// sent. Events are picked randomly. Default is null (disabled)
  double sampleRate;

  final List<String> _inAppExcludes = [];

  /// A list of string prefixes of module names that do not belong to the app, but rather third-party
  /// packages. Modules considered not to be part of the app will be hidden from stack traces by
  /// default.
  List<String> get inAppExcludes => List.unmodifiable(_inAppExcludes);

  final List<String> _inAppIncludes = [];

  /// A list of string prefixes of module names that belong to the app. This option takes precedence
  /// over inAppExcludes.
  List<String> get inAppIncludes => List.unmodifiable(_inAppIncludes);

  Transport _transport = NoOpTransport();

  Transport get transport => _transport;

  set transport(Transport transport) => _transport = transport ?? _transport;

  /// Sets the distribution. Think about it together with release and environment
  String dist;

  /// The server name used in the Sentry messages.
  String serverName;

  Sdk _sdk = Sdk(name: sdkName, version: sdkVersion);

  /// Sdk object that contains the Sentry Client Name and its version
  Sdk get sdk => _sdk;

  set sdk(Sdk sdk) {
    _sdk = sdk ?? _sdk;
  }

  bool _enableAutoSessionTracking = true;

  bool get enableAutoSessionTracking => _enableAutoSessionTracking;

  set enableAutoSessionTracking(bool enableAutoSessionTracking) {
    _enableAutoSessionTracking =
        enableAutoSessionTracking ?? _enableAutoSessionTracking;
  }

  bool _enableNativeCrashHandling = true;

  bool get enableNativeCrashHandling => _enableNativeCrashHandling;

  set enableNativeCrashHandling(bool nativeCrashHandling) {
    _enableNativeCrashHandling =
        nativeCrashHandling ?? _enableNativeCrashHandling;
  }

  bool _attachStacktrace = true;

  bool get attachStacktrace => _attachStacktrace;

  set attachStacktrace(bool attachStacktrace) {
    _attachStacktrace = attachStacktrace ?? _attachStacktrace;
  }

  int _autoSessionTrackingIntervalMillis = 30000;

  int get autoSessionTrackingIntervalMillis =>
      _autoSessionTrackingIntervalMillis;

  set autoSessionTrackingIntervalMillis(int autoSessionTrackingIntervalMillis) {
    _autoSessionTrackingIntervalMillis =
        (autoSessionTrackingIntervalMillis != null &&
                autoSessionTrackingIntervalMillis >= 0)
            ? autoSessionTrackingIntervalMillis
            : _autoSessionTrackingIntervalMillis;
  }

  int _anrTimeoutIntervalMillis = 5000;

  int get anrTimeoutIntervalMillis => _anrTimeoutIntervalMillis;

  set anrTimeoutIntervalMillis(int anrTimeoutIntervalMillis) {
    _anrTimeoutIntervalMillis =
        (anrTimeoutIntervalMillis != null && anrTimeoutIntervalMillis >= 0)
            ? anrTimeoutIntervalMillis
            : _anrTimeoutIntervalMillis;
  }

  bool _enableAutoNativeBreadcrumbs = true;

  get enableAutoNativeBreadcrumbs => _enableAutoNativeBreadcrumbs;

  set enableAutoNativeBreadcrumbs(bool enableAutoNativeBreadcrumbs) {
    _enableAutoNativeBreadcrumbs =
        enableAutoNativeBreadcrumbs ?? _enableAutoNativeBreadcrumbs;
  }

  int _cacheDirSize = 30;

  int get cacheDirSize => _cacheDirSize;

  set cacheDirSize(int cacheDirSize) {
    _cacheDirSize = (cacheDirSize != null && cacheDirSize >= 0)
        ? cacheDirSize
        : _cacheDirSize;
  }

  // TODO: Scope observers, enableScopeSync

  // TODO: sendDefaultPii

  // TODO: those ctor params could be set on Sentry._setDefaultConfiguration or instantiate by default here
  SentryOptions({this.dsn}) {
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

typedef BeforeSendCallback = SentryEvent Function(
    SentryEvent event, dynamic hint);

typedef BeforeBreadcrumbCallback = Breadcrumb Function(
  Breadcrumb breadcrumb,
  dynamic hint,
);

typedef EventProcessor = SentryEvent Function(SentryEvent event, dynamic hint);

typedef Integration = FutureOr<void> Function(Hub hub, SentryOptions options);

typedef Logger = Function(SentryLevel level, String message);

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

void noOpLogger(SentryLevel level, String message) {}

void dartLogger(SentryLevel level, String message) {
  print('[$level] $message');
}
