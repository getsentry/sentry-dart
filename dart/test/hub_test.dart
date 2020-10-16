import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/hub.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Hub instanciation', () {
    test('should not instanciate without a sentryOptions', () {
      Hub hub;
      expect(() => hub = Hub(null), throwsArgumentError);
      expect(hub, null);
    });

    test('should not instanciate without a dsn', () {
      expect(() => Hub(SentryOptions()), throwsArgumentError);
    });

    test('should instanciate with a dsn', () {
      final hub = Hub(SentryOptions(dsn: fakeDns));
      expect(hub.isEnabled, true);
    });
  });

  group('Hub captures', () {
    Hub hub;
    SentryOptions options;
    MockSentryClient client;

    setUp(() {
      options = SentryOptions(dsn: fakeDns);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should capture event', () {
      hub.captureEvent(fakeEvent);
      verify(client.captureEvent(event: fakeEvent)).called(1);
    });

    test('should capture exception', () {
      hub.captureException(fakeException);

      verify(client.captureException(fakeException)).called(1);
    });

    test('should capture message', () {
      hub.captureMessage(fakeMessage, level: SeverityLevel.info);
      verify(
        client.captureMessage(fakeMessage, level: SeverityLevel.info),
      ).called(1);
    });
  });

  group('Close hub', () {
    test('should close an enabled hub', () {
      final hub = Hub(SentryOptions(dsn: fakeDns));
      final client = MockSentryClient();
      hub.bindClient(client);
      hub.close();

      expect(hub.isEnabled, false);
      verify(client.close()).called(1);
    });
  });
}
