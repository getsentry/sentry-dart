import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('SentryClient sampling', () {
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('captures event, sample rate is 100% enabled', () {
      options.sampleRate = 1.0;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });

    test('do not capture event, sample rate is 0% disabled', () {
      options.sampleRate = 0.0;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verifyNever(options.transport.send(any));
    });

    test('captures event, sample rate is null, disabled', () {
      options.sampleRate = null;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });
  });

  group('SentryClient before send', () {
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('before send drops event', () {
      options.beforeSendCallback = beforeSendCallbackDropEvent;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verifyNever(options.transport.send(any));
    });

    test('before send returns an event and event is captured', () {
      options.beforeSendCallback = beforeSendCallback;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });
  });
}

SentryEvent beforeSendCallbackDropEvent(SentryEvent event, dynamic hint) =>
    null;

SentryEvent beforeSendCallback(SentryEvent event, dynamic hint) => event;
