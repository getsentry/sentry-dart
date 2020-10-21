// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// A pure Dart client for Sentry.io crash reporting.
import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/transport.dart';

import 'client.dart';
import 'protocol.dart';

SentryClient createSentryClient(SentryOptions options) =>
    SentryIOClient(options);

/// Logs crash reports and events to the Sentry.io service.
class SentryIOClient extends SentryClient {
  /// Instantiates a client using [SentryOptions]
  factory SentryIOClient(SentryOptions options) =>
      SentryIOClient._(options, platform: sdkPlatform);

  static const sdk = Sdk(name: sdkName, version: sdkVersion);

  SentryIOClient._(SentryOptions options, {@required String platform})
      : super.base(
          options,
          transport: Transport(
            compressPayload: options.compressPayload,
            httpClient: options.httpClient,
            clock: options.clock,
            sdk: sdk,
            dsn: options.dsn,
            headersBuilder: buildHeaders,
            platform: platform,
          ),
        );

  @protected
  static Map<String, String> buildHeaders(String authHeader) {
    final headers = SentryClient.buildHeaders(authHeader);

    // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
    // for web it use browser user agent
    headers['User-Agent'] = sdk.identifier;

    return headers;
  }
}
