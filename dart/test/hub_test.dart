import 'package:sentry/sentry.dart';
import 'package:sentry/src/hub.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Hub instanciation', () {
    test('should not instanciate without a sentryOptions', () {
      expect(() => Hub(null), throwsArgumentError);
    });

    test('should not instanciate without a dsn', () {
      expect(() => Hub(SentryOptions()), throwsArgumentError);
    });

    test('should instanciate with a dsn', () {
      final hub = Hub(SentryOptions(dsn: fakeDns));
      expect(hub.isEnabled, true);
    });
  });
}
