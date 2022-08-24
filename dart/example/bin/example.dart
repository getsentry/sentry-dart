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
      'https://fe85fc5123d44d5c99202d9e8f09d52e@395f015cf6c1.eu.ngrok.io/2';

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

  // accessToProfilingRollout
  final accessToProfilingRollout = await Sentry.isFeatureFlagEnabled(
    'accessToProfiling',
    defaultValue: false,
    context: (myContext) => {
      myContext.tags['userSegment'] = 'slow',
    },
  );
  print(
      'accessToProfilingRollout $accessToProfilingRollout'); // false for user 800

  // accessToProfilingMatch
  final accessToProfilingMatch = await Sentry.isFeatureFlagEnabled(
    'accessToProfiling',
    defaultValue: false,
    context: (myContext) => {
      myContext.tags['isSentryDev'] = 'true',
    },
  );
  print('accessToProfilingMatch $accessToProfilingMatch'); // returns true

  // profilingEnabledMatch
  final profilingEnabledMatch = await Sentry.isFeatureFlagEnabled(
    'profilingEnabled',
    defaultValue: false,
    context: (myContext) => {
      myContext.tags['isSentryDev'] = 'true',
    },
  );
  print('profilingEnabledMatch $profilingEnabledMatch'); // returns true

  // profilingEnabledRollout
  final profilingEnabledRollout = await Sentry.isFeatureFlagEnabled(
    'profilingEnabled',
    defaultValue: false,
  );
  print(
      'profilingEnabledRollout $profilingEnabledRollout'); // false for user 800

  // loginBannerMatch
  final loginBannerMatch = await Sentry.getFeatureFlagValue<String>(
    'loginBanner',
    defaultValue: 'banner0',
    context: (myContext) => {
      myContext.tags['isSentryDev'] = 'true',
    },
  );
  print('loginBannerMatch $loginBannerMatch'); // returns banner1

  // loginBannerMatch2
  final loginBannerMatch2 = await Sentry.getFeatureFlagValue<String>(
    'loginBanner',
    defaultValue: 'banner0',
  );
  print('loginBannerMatch2 $loginBannerMatch2'); // returns banner2

  // tracesSampleRate
  final tracesSampleRate = await Sentry.getFeatureFlagValue<double>(
    'tracesSampleRate',
    defaultValue: 0.0,
  );
  print('tracesSampleRate $tracesSampleRate'); // returns 0.25

  // final flag = await Sentry.getFeatureFlagInfo('loginBanner',
  //     context: (myContext) => {
  //           myContext.tags['myCustomTag'] = 'true',
  //         });

  // print(flag?.payload?['internal_setting'] ?? 'whaat');
  // print(flag?.payload ?? {});
}

Future<void> runApp() async {}
