import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../protocol.dart';
import '../throwable_mechanism.dart';
import '../utils.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// An event to be reported to Sentry.io.
class SentryEvent with SentryEventLike<SentryEvent> {
  /// Creates an event.
  SentryEvent({
    SentryId? eventId,
    DateTime? timestamp,
    Map<String, String>? modules,
    Map<String, String>? tags,
    @Deprecated(
        'Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    List<Breadcrumb>? breadcrumbs,
    List<SentryException>? exceptions,
    List<SentryThread>? threads,
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
    this.level,
    this.culprit,
    this.user,
    Contexts? contexts,
    this.request,
    this.debugMeta,
    this.type,
    this.unknown,
  })  : eventId = eventId ?? SentryId.newId(),
        timestamp = timestamp ?? getUtcDateTime(),
        contexts = contexts ?? Contexts(),
        modules = modules != null ? Map.from(modules) : null,
        tags = tags != null ? Map.from(tags) : null,
        // ignore: deprecated_member_use_from_same_package
        extra = extra != null ? Map.from(extra) : null,
        fingerprint = fingerprint != null ? List.from(fingerprint) : null,
        breadcrumbs = breadcrumbs != null ? List.from(breadcrumbs) : null,
        exceptions = exceptions != null ? List.from(exceptions) : null,
        threads = threads != null ? List.from(threads) : null,
        _throwable = throwable;

  /// Refers to the default fingerprinting algorithm.
  ///
  /// You do not need to specify this value unless you supplement the default
  /// fingerprint with custom fingerprints.
  static const String defaultFingerprint = '{{ default }}';

  /// The ID Sentry.io assigned to the submitted event for future reference.
  SentryId eventId;

  /// A timestamp representing when the event occurred.
  DateTime? timestamp;

  /// A string representing the platform the SDK is submitting from. This will be used by the Sentry interface to customize various components in the interface.
  String? platform;

  /// The logger that logged the event.
  String? logger;

  /// Identifies the server that logged this event.
  String? serverName;

  /// The version of the application that logged the event.
  String? release;

  /// The distribution of the application.
  String? dist;

  /// The environment that logged the event, e.g. "production", "staging".
  String? environment;

  /// A list of relevant modules and their versions.
  Map<String, String>? modules;

  /// Event message.
  ///
  /// Generally an event either contains a [message] or [exceptions].
  SentryMessage? message;

  dynamic _throwable;

  /// An object that was thrown.
  ///
  /// It's `runtimeType` and `toString()` are logged.
  /// If it's an Error, with a stackTrace, the stackTrace is logged.
  /// If this behavior is undesirable, consider using a custom formatted
  /// [message] instead.
  dynamic get throwable =>
      (_throwable is ThrowableMechanism) ? _throwable.throwable : _throwable;

  /// A throwable decorator that holds a [Mechanism] related to the decorated
  /// [throwable]
  ///
  /// Use the [throwable] directly if you don't want the decorated throwable
  dynamic get throwableMechanism => _throwable;

  /// One or multiple chained (nested) exceptions that occurred in a program.
  List<SentryException>? exceptions;

  /// The Threads Interface specifies threads that were running at the time an
  /// event happened. These threads can also contain stack traces.
  /// Typically not needed in Dart applications.
  List<SentryThread>? threads;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  String? transaction;

  /// How important this event is.
  SentryLevel? level;

  /// What caused this event to be logged.
  String? culprit;

  /// Name/value pairs that events can be searched by.
  Map<String, String>? tags;

  /// Arbitrary name/value pairs attached to the event.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  @Deprecated(
      'Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
  Map<String, dynamic>? extra;

  /// List of breadcrumbs for this event.
  ///
  /// See also:
  /// * https://docs.sentry.io/platforms/dart/enriching-events/breadcrumbs/
  /// * https://docs.sentry.io/platforms/flutter/enriching-events/breadcrumbs/
  List<Breadcrumb>? breadcrumbs;

  /// Information about the current user.
  ///
  /// The value in this field overrides the user context
  /// set in [Scope.user] for this logged event.
  SentryUser? user;

  /// The context interfaces provide additional context data.
  /// Typically this is data related to the current user,
  /// the current HTTP request.
  Contexts contexts;

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// If not specified a default deduplication fingerprint is used. The default
  /// fingerprint may be supplemented by additional fingerprints by specifying
  /// multiple values. The default fingerprint can be specified by adding
  /// [defaultFingerprint] to the list in addition to your custom values.
  ///
  /// Examples:
  /// ```dart
  /// // A completely custom fingerprint:
  /// var custom = ['foo', 'bar', 'baz'];
  /// // A fingerprint that supplements the default one with value 'foo':
  /// var supplemented = [SentryEvent.defaultFingerprint, 'foo'];
  /// ```
  List<String>? fingerprint;

  /// The SDK Interface describes the Sentry SDK and its configuration used
  /// to capture and transmit an event.
  SdkVersion? sdk;

  /// Contains information on a HTTP request related to the event.
  /// In client, this can be an outgoing request, or the request that rendered
  /// the current web page.
  /// On server, this could be the incoming web request that is being handled
  SentryRequest? request;

  /// The debug meta interface carries debug information for processing errors
  /// and crash reports.
  DebugMeta? debugMeta;

  /// The event type determines how Sentry handles the event and has an impact
  /// on processing, rate limiting, and quotas.
  /// defaults to 'default'
  String? type;

  @internal
  final Map<String, dynamic>? unknown;

  @Deprecated('Assign values directly to the instance.')
  @override
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
    SentryLevel? level,
    String? culprit,
    Map<String, String>? tags,
    @Deprecated(
        'Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    SentryUser? user,
    Contexts? contexts,
    List<Breadcrumb>? breadcrumbs,
    SdkVersion? sdk,
    SentryRequest? request,
    DebugMeta? debugMeta,
    List<SentryException>? exceptions,
    List<SentryThread>? threads,
    String? type,
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
        level: level ?? this.level,
        culprit: culprit ?? this.culprit,
        tags: (tags != null ? Map.from(tags) : null) ?? this.tags,
        // ignore: deprecated_member_use_from_same_package
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
        exceptions: (exceptions != null ? List.from(exceptions) : null) ??
            this.exceptions,
        threads: (threads != null ? List.from(threads) : null) ?? this.threads,
        type: type ?? this.type,
        unknown: unknown,
      );

  /// Deserializes a [SentryEvent] from JSON [Map].
  factory SentryEvent.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    final breadcrumbsJson = json.getValueOrNull<List<dynamic>>('breadcrumbs');
    final breadcrumbs = breadcrumbsJson
        ?.map((e) => Breadcrumb.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList(growable: false);

    final threadsJson = json.getValueOrNull<Map<String, dynamic>>('threads');
    final threadValues = threadsJson?.getValueOrNull<List<dynamic>>('values');
    final threads = threadValues
        ?.map((e) => SentryThread.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList(growable: false);

    final exceptionsJson =
        json.getValueOrNull<Map<String, dynamic>>('exception');
    final exceptionValues =
        exceptionsJson?.getValueOrNull<List<dynamic>>('values');
    final exceptions = exceptionValues
        ?.map((e) => SentryException.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList(growable: false);

    final modulesJson = json.getValueOrNull<Map<String, dynamic>>('modules');
    final tagsJson = json.getValueOrNull<Map<String, dynamic>>('tags');
    final modules =
        modulesJson == null ? null : Map<String, String>.from(modulesJson);
    final tags = tagsJson == null ? null : Map<String, String>.from(tagsJson);

    final timestamp = json.getValueOrNull<DateTime>('timestamp');
    final levelJson = json.getValueOrNull<String>('level');
    final fingerprintJson = json.getValueOrNull<List<dynamic>>('fingerprint');
    final sdkVersionJson = json.getValueOrNull<Map<String, dynamic>>('sdk');
    final messageJson = json.getValueOrNull<Map<String, dynamic>>('message');
    final userJson = json.getValueOrNull<Map<String, dynamic>>('user');
    final contextsJson = json.getValueOrNull<Map<String, dynamic>>('contexts');
    final requestJson = json.getValueOrNull<Map<String, dynamic>>('request');
    final debugMetaJson =
        json.getValueOrNull<Map<String, dynamic>>('debug_meta');

    var extra = json.getValueOrNull<Map<String, dynamic>>('extra');
    if (extra != null) {
      extra = Map<String, dynamic>.from(extra);
    }

    return SentryEvent(
      eventId: SentryId.fromId(json.getValueOrNull('event_id')!),
      timestamp: timestamp,
      modules: modules,
      tags: tags,
      // ignore: deprecated_member_use_from_same_package
      extra: extra,
      fingerprint:
          fingerprintJson?.map((e) => e as String).toList(growable: false),
      breadcrumbs: breadcrumbs,
      sdk: sdkVersionJson != null && sdkVersionJson.isNotEmpty
          ? SdkVersion.fromJson(Map<String, dynamic>.from(sdkVersionJson))
          : null,
      platform: json.getValueOrNull('platform'),
      logger: json.getValueOrNull('logger'),
      serverName: json.getValueOrNull('server_name'),
      release: json.getValueOrNull('release'),
      dist: json.getValueOrNull('dist'),
      environment: json.getValueOrNull('environment'),
      message: messageJson != null && messageJson.isNotEmpty
          ? SentryMessage.fromJson(Map<String, dynamic>.from(messageJson))
          : null,
      transaction: json.getValueOrNull('transaction'),
      threads: threads,
      level: levelJson != null ? SentryLevel.fromName(levelJson) : null,
      culprit: json.getValueOrNull('culprit'),
      user: userJson != null && userJson.isNotEmpty
          ? SentryUser.fromJson(Map<String, dynamic>.from(userJson))
          : null,
      contexts: contextsJson != null && contextsJson.isNotEmpty
          ? Contexts.fromJson(Map<String, dynamic>.from(contextsJson))
          : null,
      request: requestJson != null && requestJson.isNotEmpty
          ? SentryRequest.fromJson(Map<String, dynamic>.from(requestJson))
          : null,
      debugMeta: debugMetaJson != null && debugMetaJson.isNotEmpty
          ? DebugMeta.fromJson(Map<String, dynamic>.from(debugMetaJson))
          : null,
      exceptions: exceptions,
      type: json.getValueOrNull('type'),
      unknown: json.notAccessed(),
    );
  }

  /// Serializes this event to JSON.
  Map<String, dynamic> toJson() {
    var messageMap = message?.toJson();
    final contextsMap = contexts.toJson();
    final userMap = user?.toJson();
    final sdkMap = sdk?.toJson();
    final requestMap = request?.toJson();
    final debugMetaMap = debugMeta?.toJson();
    final exceptionsJson = exceptions
        ?.map((e) => e.toJson())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    // Thread serialization is tricky:
    // - Thread should not have a stacktrace when an exception is connected to it
    // - Thread should serializae a stacktrace when no exception is connected to it

    // These are the thread ids with a connected exception
    final threadIds = exceptions
        ?.map((element) => element.threadId)
        .where((element) => element != null)
        .toSet();

    final threadJson = threads
        ?.map((element) {
          if (threadIds?.contains(element.id) ?? false) {
            // remove thread.stacktrace if a connected exception exists
            final json = element.toJson();
            json.remove('stacktrace');
            return json;
          }
          return element.toJson();
        })
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return {
      ...?unknown,
      'event_id': eventId.toString(),
      if (timestamp != null)
        'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp!),
      if (platform != null) 'platform': platform,
      if (logger != null) 'logger': logger,
      if (serverName != null) 'server_name': serverName,
      if (release != null) 'release': release,
      if (dist != null) 'dist': dist,
      if (environment != null) 'environment': environment,
      if (modules != null && modules!.isNotEmpty) 'modules': modules,
      if (transaction != null) 'transaction': transaction,
      if (level != null) 'level': level!.name,
      if (culprit != null) 'culprit': culprit,
      if (tags?.isNotEmpty ?? false) 'tags': tags,
      // ignore: deprecated_member_use_from_same_package
      if (extra?.isNotEmpty ?? false) 'extra': extra,
      if (type != null) 'type': type,
      if (fingerprint?.isNotEmpty ?? false) 'fingerprint': fingerprint,
      if (breadcrumbs?.isNotEmpty ?? false)
        'breadcrumbs':
            breadcrumbs?.map((b) => b.toJson()).toList(growable: false),
      if (messageMap?.isNotEmpty ?? false) 'message': messageMap,
      if (contextsMap.isNotEmpty) 'contexts': contextsMap,
      if (userMap?.isNotEmpty ?? false) 'user': userMap,
      if (sdkMap?.isNotEmpty ?? false) 'sdk': sdkMap,
      if (requestMap?.isNotEmpty ?? false) 'request': requestMap,
      if (debugMetaMap?.isNotEmpty ?? false) 'debug_meta': debugMetaMap,
      if (exceptionsJson?.isNotEmpty ?? false)
        'exception': {'values': exceptionsJson},
      if (threadJson?.isNotEmpty ?? false) 'threads': {'values': threadJson},
    };
  }

  // Returns first non-null stack trace of this event
  @internal
  SentryStackTrace? get stacktrace =>
      exceptions?.firstWhereOrNull((e) => e.stackTrace != null)?.stackTrace ??
      threads?.firstWhereOrNull((t) => t.stacktrace != null)?.stacktrace;
}
