import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Sentry static entry', () {
    SentryClient client;

    Exception anException;

    setUp(() {
      Sentry.init((options) => options.dsn = fakeDsn);
      anException = Exception('anException');

      client = MockSentryClient();
      Sentry.initClient(client);
    });

    test('should capture the event', () {
      Sentry.captureEvent(fakeEvent);
      verify(
        client.captureEvent(
          fakeEvent,
          scope: anyNamed('scope'),
          stackFrameFilter: null,
        ),
      ).called(1);
    });

    test('should not capture a null event', () async {
      await Sentry.captureEvent(null);
      verifyNever(client.captureEvent(fakeEvent));
    });

    test('should not capture a null exception', () async {
      await Sentry.captureException(null);
      verifyNever(
        client.captureException(
          any,
          stackTrace: anyNamed('stackTrace'),
        ),
      );
    });

    test('should capture the exception', () async {
      await Sentry.captureException(anException);
      verify(
        client.captureException(anException,
            stackTrace: null, scope: anyNamed('scope')),
      ).called(1);
    });
  });
}
