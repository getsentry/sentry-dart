// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
import 'dart:html' show window;

import 'sentry_client.dart';
import 'sentry_options.dart';

SentryClient createSentryClient(SentryOptions options) =>
    SentryBrowserClient(options);

/// Logs crash reports and events to the Sentry.io service.
class SentryBrowserClient extends SentryClient {
  /// Instantiates a client using [dsn] issued to your project by Sentry.io as
  /// the endpoint for submitting events.
  ///
  /// If [httpClient] is provided, it is used instead of the default client to
  /// make HTTP calls to Sentry.io. This is useful in tests.
  factory SentryBrowserClient(SentryOptions options) =>
      SentryBrowserClient._(options);

  SentryBrowserClient._(SentryOptions options)
      // origin is necessary for sentry to resolve stacktrace
      : super.base(options, origin: '${window.location.origin}/');
}
