// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:sentry/sentry.dart';

import 'event_example.dart';

/// Sends a test exception report to Sentry.io using this Dart client.
Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  // const dsn =
  //     'https://9934c532bf8446ef961450973c898537@o447951.ingest.sentry.io/5428562';
  const dsn =
      'https://60d3409215134fd1a60765f2400b6b38@ac75-72-74-53-151.ngrok.io/1';

  await Sentry.init(
    (options) => options
      ..dsn = dsn
      ..debug = true
      ..release = 'myapp@1.0.0+1'
      ..environment = 'prod',
    appRunner: runApp,
  );
  await Sentry.configureScope((scope) async {
    await scope.setUser(
      SentryUser(
        id: '800',
      ),
    );
    // await scope.setTag('isSentryDev', 'true');
  });

  final enabled = await Sentry.isFeatureFlagEnabled(
    'tracesSampleRate',
    defaultValue: false,
    context: (myContext) => {
      // myContext.tags['userSegment'] = 'slow',
    },
  );
  print(enabled);

  // TODO: does it return the active EvaluationRule? do we create a new model for that?
  final flag = await Sentry.getFeatureFlagInfo('tracesSampleRate',
      context: (myContext) => {
            myContext.tags['myCustomTag'] = 'true',
          });

  // print(flag?.payload?['internal_setting'] ?? 'whaat');
  print(flag?.payload ?? {});
}

Future<void> runApp() async {}
