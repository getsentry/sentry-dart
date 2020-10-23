import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/noop_transport.dart';

import 'diagnostic_logger.dart';
import 'hub.dart';
import 'protocol.dart';
import 'utils.dart';

/// Sentry SDK options
class SentryOptions {
  /// Default Log level if not specified Default is DEBUG
  static final SentryLevel defaultDiagnosticLevel = SentryLevel.debug;

  /// The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
  ///  just not send any events.
  String dsn;

  /// Contains [Event] attributes that are automatically mixed into all events
  /// captured through this client.
  ///
  /// This event is designed to contain static values that do not change from
  /// event to event, such as local operating system version, the version of
  /// Dart/Flutter SDK, etc. These attributes have lower precedence than those
  /// supplied in the even passed to [capture].
  SentryEvent environmentAttributes;

  /// If [compressPayload] is `true` the outgoing HTTP payloads are compressed
  /// using gzip. Otherwise, the payloads are sent in plain UTF8-encoded JSON
  /// text. If not specified, the compression is enabled by default.
  bool compressPayload = false;

  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  Client httpClient;

  /// If [clock] is provided, it is used to get time instead of the system
  /// clock. This is useful in tests. Should be an implementation of [ClockProvider].
  ClockProvider _clock;

  ClockProvider get clock => _clock;

  /// This variable controls the total amount of breadcrumbs that should be captured Default is 100
  int maxBreadcrumbs = 100;

  /// Logger interface to log useful debugging information if debug is enabled
  Logger _logger = noOpLogger;

  Logger get logger => _logger;

  set logger(Logger logger) {
    _logger = logger != null ? DiagnosticLogger(logger, this) : noOpLogger;
  }

  /// Are callbacks that run for every event. They can either return a new event which in most cases
  /// means just adding data OR return null in case the event will be dropped and not sent.
  final List<EventProcessor> _eventProcessors = [];

  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  /// Code that provides middlewares, bindings or hooks into certain frameworks or environments,
  /// along with code that inserts those bindings and activates them.
  final List<Integration> _integrations = [];

  // TODO: shutdownTimeout, flushTimeoutMillis
  // https://api.dart.dev/stable/2.10.2/dart-io/HttpClient/close.html doesn't have a timeout param, we'd need to implement manually

  List<Integration> get integrations => List.unmodifiable(_integrations);

  /// Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
  /// information if something goes wrong. Default is disabled.
  bool debug = false;

  /// minimum LogLevel to be used if debug is enabled
  SentryLevel _diagnosticLevel = defaultDiagnosticLevel;

  set diagnosticLevel(SentryLevel level) {
    _diagnosticLevel = level ?? defaultDiagnosticLevel;
  }

  SentryLevel get diagnosticLevel => _diagnosticLevel;

  /// Sentry client name used for the HTTP authHeader and userAgent eg
  /// sentry.{language}.{platform}/{version} eg sentry.java.android/2.0.0 would be a valid case
  String sentryClientName;

  /// This function is called with an SDK specific event object and can return a modified event
  /// object or nothing to skip reporting the event
  BeforeSendCallback beforeSendCallback;

  /// This function is called with an SDK specific breadcrumb object before the breadcrumb is added
  /// to the scope. When nothing is returned from the function, the breadcrumb is dropped
  BeforeBreadcrumbCallback beforeBreadcrumbCallback;

  /// Sets the release. SDK will try to automatically configure a release out of the box
  String release;

// TODO: probably its part of environmentAttributes
  /// Sets the environment. This string is freeform and not set by default. A release can be
  /// associated with more than one environment to separate them in the UI Think staging vs prod or
  /// similar.
  String environment;

  /// Configures the sample rate as a percentage of events to be sent in the range of 0.0 to 1.0. if
  /// 1.0 is set it means that 100% of events are sent. If set to 0.1 only 10% of events will be
  /// sent. Events are picked randomly. Default is null (disabled)
  double sampleRate;

  /// A list of string prefixes of module names that do not belong to the app, but rather third-party
  /// packages. Modules considered not to be part of the app will be hidden from stack traces by
  /// default.
  final List<String> _inAppExcludes = [];

  List<String> get inAppExcludes => List.unmodifiable(_inAppExcludes);

  /// A list of string prefixes of module names that belong to the app. This option takes precedence
  /// over inAppExcludes.
  final List<String> _inAppIncludes = [];

  List<String> get inAppIncludes => List.unmodifiable(_inAppIncludes);

  Transport _transport = NoOpTransport();

  Transport get transport => _transport;

  set transport(Transport transport) =>
      _transport = transport ?? NoOpTransport();

  // TODO: transportGate, connectionTimeoutMillis, readTimeoutMillis, hostnameVerifier, sslSocketFactory, proxy

  /// Sets the distribution. Think about it together with release and environment
  String dist;

  /// The server name used in the Sentry messages.
  String serverName;

  /// SdkVersion object that contains the Sentry Client Name and its version
  Sdk sdkVersion;

  // TODO: Scope observers, enableScopeSync

  // TODO: sendDefaultPii

  // TODO: those ctor params could be set on Sentry._setDefaultConfiguration or instantiate by default here
  SentryOptions({
    this.dsn,
    this.environmentAttributes,
    this.compressPayload,
    this.httpClient,
    Transport transport,
    ClockProvider clock = getUtcDateTime,
  }) : _transport = transport ?? NoOpTransport() {
    _clock = clock;
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

typedef Integration = Function(Hub hub, SentryOptions options);

typedef Logger = Function(SentryLevel level, String message);

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

void noOpLogger(SentryLevel level, String message) {}

void dartLogger(SentryLevel level, String message) {
  print('[$level] $message');
}
