// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:sentry/sentry.dart';

import 'event_example.dart';

/// Sends a test exception report to Sentry.io using this Dart client.
Future<void> main(List<String> rawArgs) async {
  if (rawArgs.length != 1) {
    stderr.writeln(
      'Expected exactly one argument, which is the DSN issued by Sentry.io to your project.',
    );
    exit(1);
  }

  final dsn = rawArgs.single;
  Sentry.init((options) => options..dsn = dsn);

  Sentry.addBreadcrumb(
    Breadcrumb(
        message: 'UI Lifecycle',
        timestamp: DateTime.now().toUtc(),
        category: 'ui.lifecycle',
        type: 'navigation',
        data: {'screen': 'MainActivity', 'state': 'created'},
        level: SentryLevel.info),
  );

  Sentry.configureScope((scope) {
    scope
      ..user = User(
        id: '800',
        username: 'first-user',
        email: 'first@user.lan',
        ipAddress: '127.0.0.1',
        extras: <String, String>{'first-sign-in': '2020-01-01'},
      )
      ..fingerprint = ['example-dart']
      ..transaction = '/example/app'
      ..level = SentryLevel.warning
      ..setTag('project-id', '7371')
      ..setExtra('company-name', 'Dart Inc');
  });

  print('\nReporting a complete event example: ');

  // Sends a full Sentry event payload to show the different parts of the UI.
  final sentryId = await Sentry.captureEvent(event);

  print('Capture event result : SentryId : ${sentryId}');

  print('\nCapture message: ');

  // Sends a full Sentry event payload to show the different parts of the UI.
  final messageSentryId = await Sentry.captureMessage(
    'Message 1',
    level: SentryLevel.warning,
    template: 'Message %s',
    params: ['1'],
  );

  print('Capture message result : SentryId : ${messageSentryId}');

  try {
    await loadConfig();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    print(stackTrace);
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );

    print('Capture exception result : SentryId : ${sentryId}');
  } finally {
    await Sentry.close();
  }

  /* TODO(rxlabz) Sentry CaptureMessage(message, level) */
}

Future<void> loadConfig() async {
  await parseConfig();
}

Future<void> parseConfig() async {
  await decode();
}

Future<void> decode() async {
  throw StateError('This is a test error');
}
