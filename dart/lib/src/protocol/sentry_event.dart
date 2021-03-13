import 'package:meta/meta.dart';

import '../protocol.dart';
import '../throwable_mechanism.dart';
import '../utils.dart';

/// An event to be reported to Sentry.io.
@immutable
class SentryEvent {
  /// Creates an event.
  SentryEvent({
    SentryId? eventId,
    DateTime? timestamp,
    Map<String, String>? modules,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    List<Breadcrumb>? breadcrumbs,
    this.sdk,
    this.platform,
    this.logger,
    this.serverName,
    this.release,
    this.dist,
    this.environment,
    this.message,
    this.transaction,
    dynamic throwable,
    this.stackTrace,
    this.exception,
    this.level,
    this.culprit,
    this.user,
    Contexts? contexts,
    this.request,
    this.debugMeta,
  })  : eventId = eventId ?? SentryId.newId(),
        timestamp = timestamp ?? getUtcDateTime(),
        contexts = contexts ?? Contexts(),
        modules = modules != null ? Map.from(modules) : null,
        tags = tags != null ? Map.from(tags) : null,
        extra = extra != null ? Map.from(extra) : null,
        fingerprint = fingerprint != null ? List.from(fingerprint) : null,
        breadcrumbs = breadcrumbs != null ? List.from(breadcrumbs) : null,
        _throwable = throwable;

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
  final String? platform;

  /// The logger that logged the event.
  final String? logger;

  /// Identifies the server that logged this event.
  final String? serverName;

  /// The version of the application that logged the event.
  final String? release;

  /// The distribution of the application.
  final String? dist;

  /// The environment that logged the event, e.g. "production", "staging".
  final String? environment;

  /// A list of relevant modules and their versions.
  final Map<String, String>? modules;

  /// Event message.
  ///
  /// Generally an event either contains a [message] or an [exception].
  final SentryMessage? message;

  final dynamic _throwable;

  /// An object that was thrown.
  ///
  /// It's `runtimeType` and `toString()` are logged.
  /// If it's an Error, with a stackTrace, the stackTrace is logged.
  /// If this behavior is undesirable, consider using a custom formatted [message] instead.
  dynamic get throwable => (_throwable is ThrowableMechanism)
      ? (_throwable as ThrowableMechanism).throwable
      : _throwable;

  /// A Throwable decorator that holds a Mechanism related to the decorated Throwable
  ///
  /// Use the 'throwable' directly if you don't want the decorated Throwable
  dynamic get throwableMechanism => _throwable;

  /// an optional attached StackTrace
  /// used when event has no throwable or exception, see [SentryOptions.attachStacktrace]
  final SentryStackTrace? stackTrace;

  /// an exception or error that occurred in a program
  /// TODO more doc
  final SentryException? exception;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  final String? transaction;

  /// How important this event is.
  final SentryLevel? level;

  /// What caused this event to be logged.
  final String? culprit;

  /// Name/value pairs that events can be searched by.
  final Map<String, String>? tags;

  /// Arbitrary name/value pairs attached to the event.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic>? extra;

  /// List of breadcrumbs for this event.
  ///
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  final List<Breadcrumb>? breadcrumbs;

  /// Information about the current user.
  ///
  /// The value in this field overrides the user context
  /// set in [Scope.user] for this logged event.
  final SentryUser? user;

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
  ///     var supplemented = [SentryEvent.defaultFingerprint, 'foo'];
  final List<String>? fingerprint;

  /// The SDK Interface describes the Sentry SDK and its configuration used to capture and transmit an event.
  final SdkVersion? sdk;

  ///  contains information on a HTTP request related to the event.
  ///  In client, this can be an outgoing request, or the request that rendered the current web page.
  ///  On server, this could be the incoming web request that is being handled
  final SentryRequest? request;

  /// The debug meta interface carries debug information for processing errors and crash reports.
  final DebugMeta? debugMeta;

  SentryEvent copyWith({
    SentryId? eventId,
    DateTime? timestamp,
    String? platform,
    String? logger,
    String? serverName,
    String? release,
    String? dist,
    String? environment,
    Map<String, String>? modules,
    SentryMessage? message,
    String? transaction,
    dynamic throwable,
    SentryException? exception,
    dynamic stackTrace,
    SentryLevel? level,
    String? culprit,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    SentryUser? user,
    Contexts? contexts,
    List<Breadcrumb>? breadcrumbs,
    SdkVersion? sdk,
    SentryRequest? request,
    DebugMeta? debugMeta,
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
        modules: (modules != null ? Map.from(modules) : null) ?? this.modules,
        message: message ?? this.message,
        transaction: transaction ?? this.transaction,
        throwable: throwable ?? _throwable,
        exception: exception ?? this.exception,
        stackTrace: stackTrace ?? this.stackTrace,
        level: level ?? this.level,
        culprit: culprit ?? this.culprit,
        tags: (tags != null ? Map.from(tags) : null) ?? this.tags,
        extra: (extra != null ? Map.from(extra) : null) ?? this.extra,
        fingerprint: (fingerprint != null ? List.from(fingerprint) : null) ??
            this.fingerprint,
        user: user ?? this.user,
        contexts: contexts ?? this.contexts,
        breadcrumbs: (breadcrumbs != null ? List.from(breadcrumbs) : null) ??
            this.breadcrumbs,
        sdk: sdk ?? this.sdk,
        request: request ?? this.request,
        debugMeta: debugMeta ?? this.debugMeta,
      );

  /// Serializes this event to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['event_id'] = eventId.toString();

    json['timestamp'] = formatDateAsIso8601WithMillisPrecision(timestamp);

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

    if (modules != null && modules!.isNotEmpty) {
      json['modules'] = modules;
    }

    Map<String, dynamic> messageMap;
    if (message != null && (messageMap = message!.toJson()).isNotEmpty) {
      json['message'] = messageMap;
    }

    if (transaction != null) {
      json['transaction'] = transaction;
    }

    final exceptionMap = exception?.toJson();
    final stackTraceMap = stackTrace?.toJson();
    if (exceptionMap?.isNotEmpty ?? false) {
      json['exception'] = {
        'values': [exceptionMap].toList(growable: false)
      };
    } else if (stackTraceMap?.isNotEmpty ?? false) {
      json['threads'] = {
        'values': [
          {
            'id': 0,
            'stacktrace': stackTraceMap,
            'crashed': true,
            'name': 'Current Isolate',
          }
        ]
      };
    }

    if (level != null) {
      json['level'] = level!.name;
    }

    if (culprit != null) {
      json['culprit'] = culprit;
    }

    if (tags?.isNotEmpty ?? false) {
      json['tags'] = tags;
    }

    if (extra?.isNotEmpty ?? false) {
      json['extra'] = extra;
    }

    final contextsMap = contexts.toJson();
    if (contextsMap.isNotEmpty) {
      json['contexts'] = contextsMap;
    }

    final userMap = user?.toJson();
    if (userMap?.isNotEmpty ?? false) {
      json['user'] = userMap;
    }

    if (fingerprint?.isNotEmpty ?? false) {
      json['fingerprint'] = fingerprint;
    }

    if (breadcrumbs?.isNotEmpty ?? false) {
      json['breadcrumbs'] =
          breadcrumbs?.map((b) => b.toJson()).toList(growable: false);
    }

    final sdkMap = sdk?.toJson();
    if (sdkMap?.isNotEmpty ?? false) {
      json['sdk'] = sdkMap;
    }

    final requestMap = request?.toJson();
    if (requestMap?.isNotEmpty ?? false) {
      json['request'] = requestMap;
    }

    final debugMetaMap = debugMeta?.toJson();
    if (debugMetaMap?.isNotEmpty ?? false) {
      json['debug_meta'] = debugMetaMap;
    }

    return json;
  }
}
