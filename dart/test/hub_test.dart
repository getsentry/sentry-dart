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
      final hub = Hub(SentryOptions(dsn: fakeDsn));
      expect(hub.isEnabled, true);
    });
  });

  group('Hub captures', () {
    Hub hub;
    SentryOptions options;
    MockSentryClient client;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should capture event', () {
      hub.captureEvent(fakeEvent);
      verify(
        client.captureEvent(
          fakeEvent,
          scope: Scope(options),
          stackFrameFilter: null,
        ),
      ).called(1);
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

  group('Hub scope', () {
    Hub hub;
    SentryClient client;

    setUp(() {
      hub = Hub(SentryOptions(dsn: fakeDsn));
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should configure its scope', () {
      hub.configureScope((Scope scope) {
        scope
          ..level = SeverityLevel.debug
          ..user = fakeUser
          ..fingerprint = ['1', '2'];
      });
      hub.captureEvent(fakeEvent);

      verify(
        client.captureEvent(
          fakeEvent,
          scope: Scope(SentryOptions(dsn: fakeDsn))
            ..level = SeverityLevel.debug
            ..user = fakeUser
            ..fingerprint = ['1', '2'],
          stackFrameFilter: null,
        ),
      ).called(1);
    });
  });

  group('Hub Client', () {
    Hub hub;
    SentryClient client;
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should bind a new client', () {
      final client2 = MockSentryClient();
      hub.bindClient(client2);
      hub.captureEvent(fakeEvent);
      verify(
        client2.captureEvent(
          fakeEvent,
          scope: Scope(options),
          stackFrameFilter: null,
        ),
      ).called(1);
    });

    test('should close its client', () {
      hub.close();

      expect(hub.isEnabled, false);
      verify(client.close()).called(1);
    });
  });

  test('clones', () {
    // TODO I'm not sure how to test it
    // could we set [hub.stack] as @visibleForTesting ?
  });
}
