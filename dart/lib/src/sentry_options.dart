import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'protocol.dart';
import 'utils.dart';

typedef Logger = void Function(SeverityLevel, String);

/// Sentry SDK options
class SentryOptions {
  /// Default Log level if not specified Default is DEBUG
  static final SeverityLevel defaultDiagnosticLevel = SeverityLevel.debug;

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
  Event environmentAttributes;

  /// If [compressPayload] is `true` the outgoing HTTP payloads are compressed
  /// using gzip. Otherwise, the payloads are sent in plain UTF8-encoded JSON
  /// text. If not specified, the compression is enabled by default.
  bool compressPayload;

  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  Client httpClient;

  /// If [clock] is provided, it is used to get time instead of the system
  /// clock. This is useful in tests. Should be an implementation of [ClockProvider].
  /// This parameter is dynamic to maintain backwards compatibility with
  /// previous use of [Clock](https://pub.dartlang.org/documentation/quiver/latest/quiver.time/Clock-class.html)
  /// from [`package:quiver`](https://pub.dartlang.org/packages/quiver).
  dynamic clock;

  /// If [uuidGenerator] is provided, it is used to generate the "event_id"
  /// field instead of the built-in random UUID v4 generator. This is useful in
  /// tests.
  UuidGenerator uuidGenerator;

  int maxBreadcrumbs;

  final Logger _logger;

  Logger get logger => _logger ?? defaultLogger;

  SentryOptions({
    this.dsn,
    this.environmentAttributes,
    this.compressPayload,
    this.httpClient,
    this.clock,
    this.uuidGenerator,
    Logger logger,
    this.maxBreadcrumbs = 100,
  }) : _logger = logger;
}

void defaultLogger({SeverityLevel level, String message}) {
  print('[$level] $message');
}
