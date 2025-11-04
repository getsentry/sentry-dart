@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'sentry_native_java_web_stub.dart'
    if (dart.library.io) 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

void main() {
  // the ReplaySizeAdjustment tests assumes a constant video block size of 16
  group('ReplaySizeAdjustment', () {
    test('rounds down when remainder is less than or equal to half block size',
        () {
      expect(0.0.adjustReplaySizeToBlockSize(), 0.0);
      expect(8.0.adjustReplaySizeToBlockSize(), 0.0);
      expect(16.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(24.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(100.0.adjustReplaySizeToBlockSize(), 96.0);
    });

    test('rounds up when remainder is greater than half block size', () {
      expect(9.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(15.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(25.0.adjustReplaySizeToBlockSize(), 32.0);
      expect(108.0.adjustReplaySizeToBlockSize(), 112.0);
      expect(109.0.adjustReplaySizeToBlockSize(), 112.0);
    });

    test('returns exact value when already multiple of block size', () {
      expect(32.0.adjustReplaySizeToBlockSize(), 32.0);
      expect(48.0.adjustReplaySizeToBlockSize(), 48.0);
      expect(64.0.adjustReplaySizeToBlockSize(), 64.0);
      expect(128.0.adjustReplaySizeToBlockSize(), 128.0);
    });

    test('handles edge cases at half block size boundaries', () {
      expect(8.0.adjustReplaySizeToBlockSize(), 0.0);
      expect(24.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(40.0.adjustReplaySizeToBlockSize(), 32.0);
    });

    test('handles fractional values', () {
      expect(7.5.adjustReplaySizeToBlockSize(), 0.0);
      expect(8.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(15.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(16.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(24.5.adjustReplaySizeToBlockSize(), 32.0);
    });
  });
}
