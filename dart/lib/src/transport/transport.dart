import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:sentry/src/utils.dart';

import '../protocol.dart';
import 'body_encoder_browser.dart' if (dart.library.io) 'body_encoder.dart';

typedef BodyEncoder = List<int> Function(
  Map<String, dynamic> data,
  Map<String, String> headers, {
  bool compressPayload,
});

typedef HeadersBuilder = Map<String, String> Function(String authHeader);

class Transport {
  final Client httpClient;

  final dynamic clock;

  final Dsn _dsn;

  final Sdk sdk;

  final HeadersBuilder headersBuilder;

  final bool compressPayload;

  /// Used by sentry to differentiate browser from io environment
  final String platform;

  Transport({
    @required this.compressPayload,
    @required this.httpClient,
    @required this.clock,
    @required this.sdk,
    @required String dsn,
    @required this.headersBuilder,
    @required this.platform,
  }) : _dsn = Dsn.parse(dsn);

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

  Future<SentryId> send(Map<String, dynamic> data) async {
    final now = clock();
    var authHeader = 'Sentry sentry_version=6, sentry_client=$clientId, '
        'sentry_timestamp=${now.millisecondsSinceEpoch}, sentry_key=$publicKey';
    if (secretKey != null) {
      authHeader += ', sentry_secret=$secretKey';
    }

    mergeAttributes(_getContext(now), into: data);

    final headers = headersBuilder(authHeader);

    final body = bodyEncoder(data, headers, compressPayload: compressPayload);

    final response = await httpClient.post(
      postUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      return SentryId.empty();
    }

    final eventId = json.decode(response.body)['id'];
    return eventId != null ? SentryId.fromId(eventId) : SentryId.empty();
  }

  Map<String, dynamic> _getContext(DateTime now) => {
        'project': projectId,
        'timestamp': formatDateAsIso8601WithSecondPrecision(now),
        'platform': platform,
      };
}
