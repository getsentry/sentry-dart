// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/src/protocol/sentry_device.dart';
import 'package:test/test.dart';

import 'package:sentry/src/utils.dart';

void main() {
  group('formatDateAsIso8601WithSecondPrecision', () {
    test('strips sub-millisecond parts', () {
      final testDate =
          DateTime.fromMillisecondsSinceEpoch(1502467721598, isUtc: true);
      expect(testDate.toIso8601String(), '2017-08-11T16:08:41.598Z');
      expect(formatDateAsIso8601WithMillisPrecision(testDate),
          '2017-08-11T16:08:41.598Z');
    });

    test('non enum returns toString serialization', () {
      final value = true;
      expect(jsonSerializationFallback(value), 'true');
    });

    test('enum returns described enum during serialization', () {
      expect(jsonSerializationFallback(SentryOrientation.landscape),
          'SentryOrientation.landscape');
    });

    test('null Object returns null during serialization', () {
      expect(jsonSerializationFallback(null), null);
    });
  });
}
