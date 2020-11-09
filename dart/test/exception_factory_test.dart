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
      } catch (err, stacktrace) {
        final mechanism = Mechanism(
          type: 'example',
          description: 'a mechanism',
        );
        sentryException = exceptionFactory.getSentryException(
          err,
          mechanism: mechanism,
          stackTrace: stacktrace,
        );
      }

      expect(sentryException.type, 'StateError');
      expect(sentryException.stacktrace.frames, isNotEmpty);
    });

    test('should not override event.stacktrace', () {
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
          stackTrace: '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''',
        );
      }

      expect(sentryException.type, 'StateError');
      expect(sentryException.stacktrace.frames.first.lineNo, 46);
      expect(sentryException.stacktrace.frames.first.colNo, 9);
      expect(sentryException.stacktrace.frames.first.fileName, 'test.dart');
    });
  });

  test("options can't be null", () {
    expect(() => SentryExceptionFactory(options: null), throwsArgumentError);
  });
}
