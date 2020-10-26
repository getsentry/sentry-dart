// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

/// A pure Dart client for Sentry.io crash reporting.
import 'client.dart';
import 'sentry_options.dart';

SentryClient createSentryClient(SentryOptions options) =>
    SentryIOClient(options);

/// Logs crash reports and events to the Sentry.io service.
class SentryIOClient extends SentryClient {
  /// Instantiates a client using [SentryOptions]
  factory SentryIOClient(SentryOptions options) {
    options.sdk ??= Sdk(name: sdkName, version: sdkVersion);
    options.httpClient ??= Client();
    return SentryIOClient._(options);
  }

  SentryIOClient._(SentryOptions options) : super.base(options);
}
