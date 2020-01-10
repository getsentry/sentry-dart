// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
@TestOn("browser")

import 'package:sentry/browser_client.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group(SentryBrowserClient, () {
    test('SentryClient constructor build browser client', () {
      final client = SentryClient(dsn: testDsn);
      expect(client is SentryBrowserClient, isTrue);
    });

    runTest(isWeb: true);
  });
}
