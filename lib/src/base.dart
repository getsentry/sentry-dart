// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:usage/uuid/uuid.dart';

import 'stack_trace.dart';
import 'utils.dart';
import 'version.dart';

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

/// Logs crash reports and events to the Sentry.io service.
abstract class SentryClientBase {
  /// Sentry.io client identifier for _this_ client.
  static const String sentryClient = '$sdkName/$sdkVersion';

  /// The default logger name used if no other value is supplied.
  static const String defaultLoggerName = 'SentryClient';

  final Client httpClient;
  ClockProvider _clock;
  final UuidGenerator _uuidGenerator;

  /// Contains [Event] attributes that are automatically mixed into all events
  /// captured through this client.
  ///
  /// This event is designed to contain static values that do not change from
  /// event to event, such as local operating system version, the version of
  /// Dart/Flutter SDK, etc. These attributes have lower precedence than those
  /// supplied in the even passed to [capture].
  final Event environmentAttributes;

  @visibleForTesting
  final Dsn _dsn;

  /// The DSN URI.
  @visibleForTesting
  Uri get dsnUri => _dsn.uri;

  /// The Sentry.io public key for the project.
  @visibleForTesting
  String get publicKey => _dsn.publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  String get secretKey => _dsn.secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  String get projectId => _dsn.projectId;

  /// Information about the current user.
  ///
  /// This information is sent with every logged event. If the value
  /// of this field is updated, all subsequent events will carry the
  /// new information.
  ///
  /// [Event.userContext] overrides the [User] context set here.
  ///
  /// See also:
  /// * https://docs.sentry.io/learn/context/#capturing-the-user
  User userContext;

  /// Use for browser stacktrace
  final String origin;

  /// Used by sentry to differentiate browser from io environment
  final String _platform;

  final String dartSdkVersion;

  SentryClientBase({
    this.httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    String dsn,
    this.environmentAttributes,
    String platform,
    this.origin,
    String dartSdkVersion,
  })  : _dsn = Dsn.parse(dsn),
        _uuidGenerator = uuidGenerator ?? _generateUuidV4WithoutDashes,
        _platform = platform ?? sdkPlatform,
        dartSdkVersion = dartSdkVersion ?? 'stable' {
    if (clock == null) {
      _clock = _getUtcDateTime;
    } else {
      _clock = clock is ClockProvider ? clock : clock.get;
    }
  }

  @visibleForTesting
  String get postUri =>
      '${dsnUri.scheme}://${dsnUri.host}/api/$projectId/store/';

  /// Reports an [event] to Sentry.io.
  Future<SentryResponse> capture({@required Event event}) async {
    final DateTime now = _clock();
    String authHeader = 'Sentry sentry_version=6, sentry_client=$sentryClient, '
        'sentry_timestamp=${now.millisecondsSinceEpoch}, sentry_key=$publicKey';
    if (secretKey != null) {
      authHeader += ', sentry_secret=$secretKey';
    }

    final Map<String, String> headers = buildHeaders(authHeader);

    final Map<String, dynamic> data = <String, dynamic>{
      'project': projectId,
      'event_id': _uuidGenerator(),
      'timestamp': formatDateAsIso8601WithSecondPrecision(now),
      'logger': defaultLoggerName,
    };

    if (environmentAttributes != null)
      mergeAttributes(environmentAttributes.toJson(), into: data);

    // Merge the user context.
    if (userContext != null) {
      mergeAttributes({'user': userContext.toJson()}, into: data);
    }

    // apply origin to event
    event = event.replace(
      origin: origin,
      dartSdkVersion: dartSdkVersion,
    );

    mergeAttributes(event.toJson(), into: data);
    mergeAttributes({'platform': _platform}, into: data);

    final body = bodyEncoder(data, headers);

    final Response response = await httpClient.post(
      postUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      String errorMessage =
          'Sentry.io responded with HTTP ${response.statusCode}';
      if (response.headers['x-sentry-error'] != null)
        errorMessage += ': ${response.headers['x-sentry-error']}';
      return new SentryResponse.failure(errorMessage);
    }

    final String eventId = json.decode(response.body)['id'];
    return new SentryResponse.success(eventId: eventId);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  Future<SentryResponse> captureException({
    @required dynamic exception,
    dynamic stackTrace,
  }) {
    final Event event = new Event(
      exception: exception,
      stackTrace: stackTrace,
    );
    return capture(event: event);
  }

  Future<Null> close() async {
    httpClient.close();
  }

  @override
  String toString() => '$SentryClientBase("$postUri")';

  @protected
  List<int> bodyEncoder(Map<String, dynamic> data, Map<String, String> headers);

  @protected
  @mustCallSuper
  Map<String, String> buildHeaders(
    String authHeader,
  ) {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (authHeader != null) {
      headers['X-Sentry-Auth'] = authHeader;
    }

    return headers;
  }
}

/// A response from Sentry.io.
///
/// If [isSuccessful] the [eventId] field will contain the ID assigned to the
/// captured event by the Sentry.io backend. Otherwise, the [error] field will
/// contain the description of the error.
@immutable
class SentryResponse {
  const SentryResponse.success({@required this.eventId})
      : isSuccessful = true,
        error = null;

  const SentryResponse.failure(this.error)
      : isSuccessful = false,
        eventId = null;

  /// Whether event was submitted successfully.
  final bool isSuccessful;

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String eventId;

  /// Error message, if the response is not successful.
  final String error;
}

typedef UuidGenerator = String Function();

String _generateUuidV4WithoutDashes() =>
    new Uuid().generateV4().replaceAll('-', '');

/// Severity of the logged [Event].
@immutable
class SeverityLevel {
  static const fatal = const SeverityLevel._('fatal');
  static const error = const SeverityLevel._('error');
  static const warning = const SeverityLevel._('warning');
  static const info = const SeverityLevel._('info');
  static const debug = const SeverityLevel._('debug');

  const SeverityLevel._(this.name);

  /// API name of the level as it is encoded in the JSON protocol.
  final String name;
}

/// Sentry does not take a timezone and instead expects the date-time to be
/// submitted in UTC timezone.
DateTime _getUtcDateTime() => new DateTime.now().toUtc();

/// An event to be reported to Sentry.io.
@immutable
class Event {
  /// Refers to the default fingerprinting algorithm.
  ///
  /// You do not need to specify this value unless you supplement the default
  /// fingerprint with custom fingerprints.
  static const String defaultFingerprint = '{{ default }}';

  /// Creates an event.
  const Event({
    this.loggerName,
    this.serverName,
    this.release,
    this.environment,
    this.message,
    this.exception,
    this.stackTrace,
    this.level,
    this.culprit,
    this.tags,
    this.extra,
    this.fingerprint,
    this.userContext,
    this.origin,
    this.dartSdkVersion,
  });

  /// path origin ot hte excepetion
  /// used in browser environment
  /// window.location.origin
  final String origin;

  final String dartSdkVersion;

  /// The logger that logged the event.
  final String loggerName;

  /// Identifies the server that logged this event.
  final String serverName;

  /// The version of the application that logged the event.
  final String release;

  /// The environment that logged the event, e.g. "production", "staging".
  final String environment;

  /// Event message.
  ///
  /// Generally an event either contains a [message] or an [exception].
  final String message;

  /// An object that was thrown.
  ///
  /// It's `runtimeType` and `toString()` are logged. If this behavior is
  /// undesirable, consider using a custom formatted [message] instead.
  final dynamic exception;

  /// The stack trace corresponding to the thrown [exception].
  ///
  /// Can be `null`, a [String], or a [StackTrace].
  final dynamic stackTrace;

  /// How important this event is.
  final SeverityLevel level;

  /// What caused this event to be logged.
  final String culprit;

  /// Name/value pairs that events can be searched by.
  final Map<String, String> tags;

  /// Arbitrary name/value pairs attached to the event.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic> extra;

  /// Information about the current user.
  ///
  /// The value in this field overrides the user context
  /// set in [SentryClient.userContext] for this logged event.
  final User userContext;

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

  /// Serializes this event to JSON.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'sdk': {
        'version': sdkVersion,
        'name': sdkName,
      },
    };

    if (loggerName != null) json['logger'] = loggerName;

    if (serverName != null) json['server_name'] = serverName;

    if (release != null) json['release'] = release;

    if (environment != null) json['environment'] = environment;

    if (message != null) json['message'] = message;

    if (exception != null) {
      json['exception'] = [
        <String, dynamic>{
          'type': '${exception.runtimeType}',
          'value': '$exception',
        }
      ];
    }

    if (stackTrace != null) {
      json['stacktrace'] = <String, dynamic>{
        'frames': encodeStackTrace(
          stackTrace,
          origin: origin,
          dartSdkVersion: dartSdkVersion,
        ),
      };
    }

    if (level != null) json['level'] = level.name;

    if (culprit != null) json['culprit'] = culprit;

    if (tags != null && tags.isNotEmpty) json['tags'] = tags;

    if (extra != null && extra.isNotEmpty) json['extra'] = extra;

    Map<String, dynamic> userContextMap;
    if (userContext != null &&
        (userContextMap = userContext.toJson()).isNotEmpty)
      json['user'] = userContextMap;

    if (fingerprint != null && fingerprint.isNotEmpty)
      json['fingerprint'] = fingerprint;

    return json;
  }

  Event replace({
    String loggerName,
    String serverName,
    String release,
    String environment,
    String message,
    exception,
    stackTrace,
    SeverityLevel level,
    String culprit,
    Map<String, String> tags,
    Map<String, dynamic> extra,
    List<String> fingerprint,
    User userContext,
    String origin,
    String dartSdkVersion,
  }) =>
      new Event(
        loggerName: loggerName ?? this.loggerName,
        serverName: serverName ?? this.serverName,
        release: release ?? this.release,
        environment: environment ?? this.environment,
        message: message ?? this.message,
        exception: exception ?? this.exception,
        stackTrace: stackTrace ?? this.stackTrace,
        extra: extra ?? this.extra,
        tags: tags ?? this.tags,
        fingerprint: fingerprint ?? this.fingerprint,
        culprit: culprit ?? this.culprit,
        userContext: userContext ?? this.userContext,
        level: level ?? this.level,
        origin: origin ?? this.origin,
        dartSdkVersion: dartSdkVersion ?? this.dartSdkVersion,
      );
}

/// Describes the current user associated with the application, such as the
/// currently signed in user.
///
/// The user can be specified globally in the [SentryClient.userContext] field,
/// or per event in the [Event.userContext] field.
///
/// You should provide at least either an [id] (a unique identifier for an
/// authenticated user) or [ipAddress] (their IP address).
///
/// Conforms to the User Interface contract for Sentry
/// https://docs.sentry.io/clientdev/interfaces/user/.
///
/// The outgoing JSON representation is:
///
/// ```
/// "user": {
///   "id": "unique_id",
///   "username": "my_user",
///   "email": "foo@example.com",
///   "ip_address": "127.0.0.1",
///   "subscription": "basic"
/// }
/// ```
class User {
  /// A unique identifier of the user.
  final String id;

  /// The username of the user.
  final String username;

  /// The email address of the user.
  final String email;

  /// The IP of the user.
  final String ipAddress;

  /// Any other user context information that may be helpful.
  ///
  /// These keys are stored as extra information but not specifically processed
  /// by Sentry.
  final Map<String, dynamic> extras;

  /// At a minimum you must set an [id] or an [ipAddress].
  const User({this.id, this.username, this.email, this.ipAddress, this.extras})
      : assert(id != null || ipAddress != null);

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "email": email,
      "ip_address": ipAddress,
      "extras": extras,
    };
  }
}

class Dsn {
  /// The Sentry.io public key for the project.
  @visibleForTesting
  final String publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  final String secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  final String projectId;

  /// The DSN URI.
  final Uri uri;

  Dsn({
    @required this.publicKey,
    @required this.projectId,
    this.uri,
    this.secretKey,
  });

  static Dsn parse(String dsn) {
    final Uri uri = Uri.parse(dsn);
    final List<String> userInfo = uri.userInfo.split(':');

    assert(() {
      if (uri.pathSegments.isEmpty)
        throw new ArgumentError(
            'Project ID not found in the URI path of the DSN URI: $dsn');

      return true;
    }());

    return Dsn(
      publicKey: userInfo[0],
      secretKey: userInfo.length >= 2 ? userInfo[1] : null,
      projectId: uri.pathSegments.last,
      uri: uri,
    );
  }
}
