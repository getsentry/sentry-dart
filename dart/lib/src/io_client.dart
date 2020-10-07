// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'utils.dart';
import 'version.dart';

SentryClient createSentryClient({
  @required String dsn,
  Event environmentAttributes,
  bool compressPayload,
  Client httpClient,
  dynamic clock,
  UuidGenerator uuidGenerator,
}) =>
    SentryIOClient(
      dsn: dsn,
      environmentAttributes: environmentAttributes,
      compressPayload: compressPayload,
      httpClient: httpClient,
      clock: clock,
      uuidGenerator: uuidGenerator,
    );

/// Logs crash reports and events to the Sentry.io service.
class SentryIOClient extends SentryClient {
  /// Instantiates a client using [dsn] issued to your project by Sentry.io as
  /// the endpoint for submitting events.
  ///
  /// [environmentAttributes] contain event attributes that do not change over
  /// the course of a program's lifecycle. These attributes will be added to
  /// all events captured via this client. The following attributes often fall
  /// under this category: [Event.serverName], [Event.release], [Event.environment].
  ///
  /// If [compressPayload] is `true` the outgoing HTTP payloads are compressed
  /// using gzip. Otherwise, the payloads are sent in plain UTF8-encoded JSON
  /// text. If not specified, the compression is enabled by default.
  ///
  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  ///
  /// If [clock] is provided, it is used to get time instead of the system
  /// clock. This is useful in tests. Should be an implementation of [ClockProvider].
  /// This parameter is dynamic to maintain backwards compatibility with
  /// previous use of [Clock](https://pub.dartlang.org/documentation/quiver/latest/quiver.time/Clock-class.html)
  /// from [`package:quiver`](https://pub.dartlang.org/packages/quiver).
  ///
  /// If [uuidGenerator] is provided, it is used to generate the "event_id"
  /// field instead of the built-in random UUID v4 generator. This is useful in
  /// tests.
  factory SentryIOClient({
    @required String dsn,
    Event environmentAttributes,
    bool compressPayload,
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
  }) {
    httpClient ??= Client();
    clock ??= getUtcDateTime;
    uuidGenerator ??= generateUuidV4WithoutDashes;
    compressPayload ??= true;

    return SentryIOClient._(
      httpClient: httpClient,
      clock: clock,
      uuidGenerator: uuidGenerator,
      environmentAttributes: environmentAttributes,
      dsn: dsn,
      compressPayload: compressPayload,
      platform: sdkPlatform,
    );
  }

  SentryIOClient._({
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    Event environmentAttributes,
    String dsn,
    this.compressPayload = true,
    String platform,
    String origin,
  }) : super.base(
          httpClient: httpClient,
          clock: clock,
          uuidGenerator: uuidGenerator,
          environmentAttributes: environmentAttributes,
          dsn: dsn,
          platform: platform,
          origin: origin,
        );

  /// Whether to compress payloads sent to Sentry.io.
  final bool compressPayload;

  @override
  Map<String, String> buildHeaders(String authHeader) {
    final headers = super.buildHeaders(authHeader);

    // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
    // for web it use browser user agent
    headers['User-Agent'] = SentryClient.sentryClient;

    return headers;
  }

  @override
  List<int> bodyEncoder(
    Map<String, dynamic> data,
    Map<String, String> headers,
  ) {
    // [SentryIOClient] implement gzip compression
    // gzip compression is not available on browser
    var body = utf8.encode(json.encode(data));
    if (compressPayload) {
      headers['Content-Encoding'] = 'gzip';
      body = gzip.encode(body);
    }
    return body;
  }
}
