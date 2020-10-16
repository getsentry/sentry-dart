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
        'Expected exactly one argument, which is the DSN issued by Sentry.io to your project.');
    exit(1);
  }

  final dsn = rawArgs.single;
  Sentry.init((options) => options.dsn = dsn);

  print('\nReporting a complete event example: ');

  // Sends a full Sentry event payload to show the different parts of the UI.
  final sentryId = await Sentry.captureEvent(event);

  print('SentryId : ${sentryId.id}');

  try {
    await foo();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    print(stackTrace);
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );

    print('SentryId : ${sentryId.id}');
  } finally {
    await Sentry.close();
  }

  /* TODO(rxlabz) Sentry CaptureMessage(message, level) */
}

Future<void> foo() async {
  await bar();
}

Future<void> bar() async {
  await baz();
}

Future<void> baz() async {
  throw StateError('This is a test error');
}
