import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sentry/src/utils.dart';

import '../protocol.dart';
import '../sentry_options.dart';
import 'body_encoder_browser.dart' if (dart.library.io) 'body_encoder.dart';
import 'header_builder_browser.dart' if (dart.library.io) 'header_builder.dart';

typedef BodyEncoder = List<int> Function(
  Map<String, dynamic> data,
  Map<String, String> headers, {
  bool compressPayload,
});

/// A transport is in charge of sending the event to the Sentry server.
class Transport {
  final SentryOptions _options;

  @visibleForTesting
  final Dsn dsn;

  /// Use for browser stacktrace
  final String origin;

  /// Used by sentry to differentiate browser from io environment
  final String platform;

  final Sdk sdk;

  Transport({
    @required SentryOptions options,
    @required this.sdk,
    @required this.platform,
    this.origin,
  })  : _options = options,
        dsn = Dsn.parse(options.dsn);

  Future<SentryId> send(SentryEvent event) async {
    final now = _options.clock();

    var authHeader = dsn.buildAuthHeader(
        timestamp: now.millisecondsSinceEpoch, clientId: sdk.identifier);
    final headers = buildHeaders(authHeader, sdk: sdk);

    final data = _getEventData(
      event,
      timeStamp: now,
    );

    final body = bodyEncoder(
      data,
      headers,
      compressPayload: _options.compressPayload,
    );

    final response = await _options.httpClient.post(
      dsn.postUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      return SentryId.empty();
    }

    final eventId = json.decode(response.body)['id'];
    return eventId != null ? SentryId.fromId(eventId) : SentryId.empty();
  }

  Map<String, dynamic> _getEventData(
    SentryEvent event, {
    DateTime timeStamp,
  }) {
    final data = <String, dynamic>{
      'event_id': event.eventId.toString(),
    };

    if (_options.environmentAttributes != null) {
      mergeAttributes(_options.environmentAttributes.toJson(), into: data);
    }

    mergeAttributes(
      event.toJson(origin: origin),
      into: data,
    );

    mergeAttributes(_getContext(timeStamp), into: data);

    return data;
  }

  Map<String, dynamic> _getContext(DateTime now) => {
        'project': dsn.projectId,
        'timestamp': formatDateAsIso8601WithSecondPrecision(now),
        'platform': platform,
      };
}
