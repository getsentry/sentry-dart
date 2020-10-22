import 'package:meta/meta.dart';

import '../protocol.dart';
import '../stack_trace.dart';
import '../utils.dart';
import '../version.dart';

/// An event to be reported to Sentry.io.
@immutable
class SentryEvent {
  /// Creates an event.
  SentryEvent({
    SentryId eventId,
    DateTime timestamp,
    String platform,
    this.logger,
    this.serverName,
    this.release,
    this.dist,
    this.environment,
    this.modules,
    this.message,
    this.transaction,
    this.exception,
    this.stackTrace,
    this.level,
    this.culprit,
    this.tags,
    this.extra,
    this.fingerprint,
    this.userContext,
    this.contexts,
    this.breadcrumbs,
    this.sdk,
  })  : eventId = eventId ?? SentryId.newId(),
        platform = platform ?? sdkPlatform,
        timestamp = timestamp ?? getUtcDateTime();

  /// Refers to the default fingerprinting algorithm.
  ///
  /// You do not need to specify this value unless you supplement the default
  /// fingerprint with custom fingerprints.
  static const String defaultFingerprint = '{{ default }}';

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final SentryId eventId;

  /// A timestamp representing when the breadcrumb occurred.
  final DateTime timestamp;

  /// A string representing the platform the SDK is submitting from. This will be used by the Sentry interface to customize various components in the interface.
  final String platform;

  /// The logger that logged the event.
  final String logger;

  /// Identifies the server that logged this event.
  final String serverName;

  /// The version of the application that logged the event.
  final String release;

  /// The distribution of the application.
  final String dist;

  /// The environment that logged the event, e.g. "production", "staging".
  final String environment;

  /// A list of relevant modules and their versions.
  final Map<String, String> modules;

  /// Event message.
  ///
  /// Generally an event either contains a [message] or an [exception].
  final Message message;

  /// An object that was thrown.
  ///
  /// It's `runtimeType` and `toString()` are logged. If this behavior is
  /// undesirable, consider using a custom formatted [message] instead.
  final dynamic exception;

  /// The stack trace corresponding to the thrown [exception].
  ///
  /// Can be `null`, a [String], or a [StackTrace].
  final dynamic stackTrace;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  final String transaction;

  /// How important this event is.
  final SentryLevel level;

  /// What caused this event to be logged.
  final String culprit;

  /// Name/value pairs that events can be searched by.
  final Map<String, String> tags;

  /// Arbitrary name/value pairs attached to the event.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic> extra;

  /// List of breadcrumbs for this event.
  ///
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  final List<Breadcrumb> breadcrumbs;

  /// Information about the current user.
  ///
  /// The value in this field overrides the user context
  /// set in [SentryClient.userContext] for this logged event.
  final User userContext;

  /// The context interfaces provide additional context data.
  /// Typically this is data related to the current user,
  /// the current HTTP request.
  final Contexts contexts;

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// If not specified a default deduplication fingerprint is used. The default
  /// fingerprint may be supplemented by additional fingerprints by specifying
  /// multiple values. The default fingerprint can be specified by adding
  /// [defaultFingerprint] to the list in addition to your custom values.
  ///
  /// Examples:
  ///
  ///     // A completely custom fingerprint:
  ///     var custom = ['foo', 'bar', 'baz'];
  ///     // A fingerprint that supplements the default one with value 'foo':
  ///     var supplemented = [Event.defaultFingerprint, 'foo'];
  final List<String> fingerprint;

  /// The SDK Interface describes the Sentry SDK and its configuration used to capture and transmit an event.
  final Sdk sdk;

  // TODO: Request and DebugMeta Interface
  // TODO: do we need a Threads interface?

  SentryEvent copyWith({
    SentryId eventId,
    DateTime timestamp,
    String platform,
    String logger,
    String serverName,
    String release,
    String dist,
    String environment,
    Map<String, String> modules,
    Message message,
    String transaction,
    dynamic exception,
    dynamic stackTrace,
    SentryLevel level,
    String culprit,
    Map<String, String> tags,
    Map<String, dynamic> extra,
    List<String> fingerprint,
    User userContext,
    Contexts contexts,
    List<Breadcrumb> breadcrumbs,
    Sdk sdk,
  }) =>
      SentryEvent(
        eventId: eventId ?? this.eventId,
        timestamp: timestamp ?? this.timestamp,
        platform: platform ?? this.platform,
        logger: logger ?? this.logger,
        serverName: serverName ?? this.serverName,
        release: release ?? this.release,
        dist: dist ?? this.dist,
        environment: environment ?? this.environment,
        modules: modules ?? this.modules,
        message: message ?? this.message,
        transaction: transaction ?? this.transaction,
        exception: exception ?? this.exception,
        stackTrace: stackTrace ?? this.stackTrace,
        level: level ?? this.level,
        culprit: culprit ?? this.culprit,
        tags: tags ?? this.tags,
        extra: extra ?? this.extra,
        fingerprint: fingerprint ?? this.fingerprint,
        userContext: userContext ?? this.userContext,
        contexts: contexts ?? this.contexts,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        sdk: sdk ?? this.sdk,
      );

  /// Serializes this event to JSON.
  Map<String, dynamic> toJson({String origin}) {
    final json = <String, dynamic>{};

    if (eventId != null) {
      json['event_id'] = eventId.toString();
    }

    if (timestamp != null) {
      json['timestamp'] = formatDateAsIso8601WithSecondPrecision(timestamp);
    }

    if (platform != null) {
      json['platform'] = platform;
    }

    if (logger != null) {
      json['logger'] = logger;
    }

    if (serverName != null) {
      json['server_name'] = serverName;
    }

    if (release != null) {
      json['release'] = release;
    }

    if (dist != null) {
      json['dist'] = dist;
    }

    if (environment != null) {
      json['environment'] = environment;
    }

    if (modules != null && modules.isNotEmpty) {
      json['modules'] = modules;
    }

    if (message != null) {
      json['message'] = message.toJson();
    }

    if (transaction != null) {
      json['transaction'] = transaction;
    }

    if (exception != null) {
      // TODO: create Exception and Mechanism Interface class
      json['exception'] = [
        <String, dynamic>{
          'type': '${exception.runtimeType}',
          'value': '$exception',
        }
      ];
      if (exception is Error && exception.stackTrace != null) {
        // TODO: create Stack Trace and Frame Interface
        json['stacktrace'] = <String, dynamic>{
          'frames': encodeStackTrace(
            exception.stackTrace,
            origin: origin,
          ),
        };
      }
    }

    if (stackTrace != null) {
      json['stacktrace'] = <String, dynamic>{
        'frames': encodeStackTrace(
          stackTrace,
          origin: origin,
        ),
      };
    }

    if (level != null) {
      json['level'] = level.name;
    }

    if (culprit != null) {
      json['culprit'] = culprit;
    }

    if (tags != null && tags.isNotEmpty) {
      json['tags'] = tags;
    }

    if (extra != null && extra.isNotEmpty) {
      json['extra'] = extra;
    }

    Map<String, dynamic> contextsMap;
    if (contexts != null && (contextsMap = contexts.toJson()).isNotEmpty) {
      json['contexts'] = contextsMap;
    }

    Map<String, dynamic> userContextMap;
    if (userContext != null &&
        (userContextMap = userContext.toJson()).isNotEmpty) {
      json['user'] = userContextMap;
    }

    if (fingerprint != null && fingerprint.isNotEmpty) {
      json['fingerprint'] = fingerprint;
    }

    if (breadcrumbs != null && breadcrumbs.isNotEmpty) {
      json['breadcrumbs'] = <String, List<Map<String, dynamic>>>{
        'values': breadcrumbs.map((b) => b.toJson()).toList(growable: false)
      };
    }

    json['sdk'] = sdk?.toJson() ??
        <String, String>{
          'name': sdkName,
          'version': sdkVersion,
        };

    return json;
  }
}
