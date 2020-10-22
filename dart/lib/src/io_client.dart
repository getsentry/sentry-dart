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
          transport: Transport(options: options, sdk: sdk, platform: platform),
        );
}
