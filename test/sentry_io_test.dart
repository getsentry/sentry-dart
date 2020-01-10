// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
@TestOn("vm")

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:sentry/src/io.dart';

import 'test_utils.dart';

void main() {
  group(SentryIOClient, () {
    test('SentryClient constructor build io client', () {
      final client = SentryClient(dsn: testDsn);
      expect(client is SentryIOClient, isTrue);
    });

    runTest(gzip: gzip);
  });
}
