import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('SentryClient sampling', () {
    SentryOptions options;
    Transport transport;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      transport = MockTransport();
    });

    test('captures event, sample rate is 100% enabled', () {
      options.sampleRate = 1.0;
      final client = SentryClient(options);
      client.transport = transport;
      client.captureEvent(fakeEvent);

      verify(client.transport.send(any)).called(1);
    });

    test('do not capture event, sample rate is 0% disabled', () {
      options.sampleRate = 0.0;
      final client = SentryClient(options);
      client.transport = transport;
      client.captureEvent(fakeEvent);

      verifyNever(client.transport.send(any));
    });

    test('do not capture event, sample rate is null', () {
      options.sampleRate = null;
      final client = SentryClient(options);
      client.transport = transport;
      client.captureEvent(fakeEvent);

      verifyNever(client.transport.send(any));
    });
  });
}
