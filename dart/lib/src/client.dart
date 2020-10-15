import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'client_stub.dart'
    if (dart.library.html) 'browser_client.dart'
    if (dart.library.io) 'io_client.dart';
import 'protocol.dart';
import 'stack_trace.dart';
import 'utils.dart';
import 'version.dart';

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

/// Logs crash reports and events to the Sentry.io service.
abstract class SentryClient {
  /// Creates a new platform appropriate client.
  ///
  /// Creates an `SentryIOClient` if `dart:io` is available and a `SentryBrowserClient` if
  /// `dart:html` is available, otherwise it will throw an unsupported error.
  factory SentryClient({
    @required String dsn,
    Event environmentAttributes,
    bool compressPayload,
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
  }) =>
      createSentryClient(
        dsn: dsn,
        environmentAttributes: environmentAttributes,
        httpClient: httpClient,
        clock: clock,
        uuidGenerator: uuidGenerator,
        compressPayload: compressPayload,
      );

  SentryClient.base({
    this.httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    String dsn,
    this.environmentAttributes,
    String platform,
    this.origin,
    Sdk sdk,
  })  : _dsn = Dsn.parse(dsn),
        _uuidGenerator = uuidGenerator ?? generateUuidV4WithoutDashes,
        _platform = platform ?? sdkPlatform,
        sdk = sdk ?? Sdk(name: sdkName, version: sdkVersion) {
    if (clock == null) {
      _clock = getUtcDateTime;
    } else {
      _clock = (clock is ClockProvider ? clock : clock.get) as ClockProvider;
    }
  }

  @protected
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

  final Dsn _dsn;

  /// The DSN URI.
  @visibleForTesting
  Uri get dsnUri => _dsn.uri;

  /// The Sentry.io public key for the project.
  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  String get publicKey => _dsn.publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
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

  final Sdk sdk;

  String get clientId => sdk.identifier;

  @visibleForTesting
  String get postUri {
    final port = dsnUri.hasPort &&
            ((dsnUri.scheme == 'http' && dsnUri.port != 80) ||
                (dsnUri.scheme == 'https' && dsnUri.port != 443))
        ? ':${dsnUri.port}'
        : '';
    final pathLength = dsnUri.pathSegments.length;
    String apiPath;
    if (pathLength > 1) {
      // some paths would present before the projectID in the dsnUri
      apiPath =
          (dsnUri.pathSegments.sublist(0, pathLength - 1) + ['api']).join('/');
    } else {
      apiPath = 'api';
    }
    return '${dsnUri.scheme}://${dsnUri.host}$port/$apiPath/$projectId/store/';
  }

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent({
    @required Event event,
    StackFrameFilter stackFrameFilter,
  }) async {
    final now = _clock();
    var authHeader = 'Sentry sentry_version=6, sentry_client=$clientId, '
        'sentry_timestamp=${now.millisecondsSinceEpoch}, sentry_key=$publicKey';
    if (secretKey != null) {
      authHeader += ', sentry_secret=$secretKey';
    }

    final headers = buildHeaders(authHeader);

    final data = <String, dynamic>{
      'project': projectId,
      'event_id': _uuidGenerator(),
      'timestamp': formatDateAsIso8601WithSecondPrecision(now),
    };

    if (environmentAttributes != null) {
      mergeAttributes(environmentAttributes.toJson(), into: data);
    }

    // Merge the user context.
    if (userContext != null) {
      mergeAttributes(<String, dynamic>{'user': userContext.toJson()},
          into: data);
    }

    mergeAttributes(
      event.toJson(
        stackFrameFilter: stackFrameFilter,
        origin: origin,
      ),
      into: data,
    );
    mergeAttributes(<String, String>{'platform': _platform}, into: data);

    final body = bodyEncoder(data, headers);

    final response = await httpClient.post(
      postUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      var errorMessage = 'Sentry.io responded with HTTP ${response.statusCode}';
      if (response.headers['x-sentry-error'] != null) {
        errorMessage += ': ${response.headers['x-sentry-error']}';
      }
      return SentryId.empty();
    }

    final eventId = '${json.decode(response.body)['id']}';
    return SentryId(eventId);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  Future<SentryId> captureException({
    @required dynamic exception,
    dynamic stackTrace,
  }) {
    final event = Event(
      exception: exception,
      stackTrace: stackTrace,
    );
    return captureEvent(event: event);
  }

  Future<void> close() async {
    httpClient.close();
  }

  @override
  String toString() => '$SentryClient("$postUri")';

  @protected
  List<int> bodyEncoder(Map<String, dynamic> data, Map<String, String> headers);

  @protected
  @mustCallSuper
  Map<String, String> buildHeaders(String authHeader) {
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
