import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('$SentryProfilingOptions', () {
    test('rejects invalid session sample rates', () {
      final options = SentryProfilingOptions()..sessionSampleRate = 1;
      for (final rate in [-0.1, 1.1, double.nan]) {
        expect(() => options.sessionSampleRate = rate, throwsArgumentError);
      }
      expect(options.sessionSampleRate, 1);
    });
  });
}
