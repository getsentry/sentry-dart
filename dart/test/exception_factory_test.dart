import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Exception factory', () {
    final options = SentryOptions(dsn: fakeDsn);
    final exceptionFactory = SentryExceptionFactory(
      options,
      SentryStackTraceFactory(options),
    );

    test('exceptionFactory.getSentryException', () {
      SentryException sentryException;
      try {
        throw StateError('a state error');
      } catch (err, stacktrace) {
        sentryException = exceptionFactory.getSentryException(
          err,
          stackTrace: stacktrace,
        );
      }

      expect(sentryException.type, 'StateError');
      expect(sentryException.stackTrace!.frames, isNotEmpty);
    });

    test('should not override event.stacktrace', () {
      SentryException sentryException;
      try {
        throw StateError('a state error');
      } catch (err) {
        sentryException = exceptionFactory.getSentryException(
          err,
          stackTrace: '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''',
        );
      }

      expect(sentryException.type, 'StateError');
      expect(sentryException.stackTrace!.frames.first.lineNo, 46);
      expect(sentryException.stackTrace!.frames.first.colNo, 9);
      expect(sentryException.stackTrace!.frames.first.fileName, 'test.dart');
    });
  });
}
