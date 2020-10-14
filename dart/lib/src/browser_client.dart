// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
import 'dart:convert';
import 'dart:html' show window;

import 'package:http/browser_client.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'utils.dart';
import 'version.dart';

SentryClient createSentryClient({
  @required String dsn,
  Event environment,
  bool compressPayload,
  Client httpClient,
  dynamic clock,
  UuidGenerator uuidGenerator,
}) =>
    SentryBrowserClient(
      dsn: dsn,
      environment: environment,
      httpClient: httpClient,
      clock: clock,
      uuidGenerator: uuidGenerator,
    );

/// Logs crash reports and events to the Sentry.io service.
class SentryBrowserClient extends SentryClient {
  /// Instantiates a client using [dsn] issued to your project by Sentry.io as
  /// the endpoint for submitting events.
  ///
  /// [environment] contain event attributes that do not change over
  /// the course of a program's lifecycle. These attributes will be added to
  /// all events captured via this client. The following attributes often fall
  /// under this category: [Event.serverName], [Event.release], [Event.environment].
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
  factory SentryBrowserClient({
    @required String dsn,
    Event environment,
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    String origin,
  }) {
    httpClient ??= BrowserClient();
    clock ??= getUtcDateTime;
    uuidGenerator ??= generateUuidV4WithoutDashes;

    // origin is necessary for sentry to resolve stacktrace
    origin ??= '${window.location.origin}/';

    return SentryBrowserClient._(
      httpClient: httpClient,
      clock: clock,
      uuidGenerator: uuidGenerator,
      environment: environment,
      dsn: dsn,
      origin: origin,
      platform: browserPlatform,
    );
  }

  SentryBrowserClient._({
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    Event environment,
    String dsn,
    String platform,
    String origin,
  }) : super.base(
          httpClient: httpClient,
          clock: clock,
          uuidGenerator: uuidGenerator,
          environment: environment,
          dsn: dsn,
          platform: platform,
          origin: origin,
          sdk: Sdk(name: browserSdkName, version: sdkVersion),
        );

  @override
  List<int> bodyEncoder(
    Map<String, dynamic> data,
    Map<String, String> headers,
  ) =>
      // Gzip compression is implicit on browser
      utf8.encode(json.encode(data));
}
