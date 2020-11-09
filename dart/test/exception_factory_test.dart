import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:test/test.dart';

void main() {
  group('Exception factory', () {
    final exceptionFactory = SentryExceptionFactory(options: SentryOptions());

    test('exceptionFactory.getSentryException', () {
      SentryException sentryException;
      try {
        throw StateError('a state error');
      } catch (err) {
        final mechanism = Mechanism(
          type: 'example',
          description: 'a mechanism',
        );
        sentryException = exceptionFactory.getSentryException(
          err,
          mechanism: mechanism,
        );
      }

      expect(sentryException.type, 'StateError');
      expect(sentryException.stacktrace.frames, isNotEmpty);
    });
  });

  test("options can't be null", () {
    expect(() => SentryExceptionFactory(options: null), throwsArgumentError);
  });
}
