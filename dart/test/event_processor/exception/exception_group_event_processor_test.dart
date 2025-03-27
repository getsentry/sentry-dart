import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'package:sentry/src/event_processor/exception/exception_group_event_processor.dart';

void main() {
  group(ExceptionGroupEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('applies grouping to exception with children', () {
      final throwableA = Exception('ExceptionA');
      final exceptionA = SentryException(
        type: 'ExceptionA',
        value: 'ExceptionA',
        throwable: throwableA,
      );
      final throwableB = Exception('ExceptionB');
      final exceptionB = SentryException(
        type: 'ExceptionB',
        value: 'ExceptionB',
        throwable: throwableB,
      );
      exceptionA.addException(exceptionB);

      var event = SentryEvent(
        throwable: throwableA,
        exceptions: [exceptionA],
      );

      final sut = fixture.getSut();
      event = (sut.apply(event, Hint()))!;

      final sentryExceptionB = event.exceptions![0];
      final sentryExceptionA = event.exceptions![1];

      expect(sentryExceptionB.throwable, throwableB);
      expect(sentryExceptionB.mechanism?.type, "chained");
      expect(sentryExceptionB.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionB.mechanism?.exceptionId, 1);
      expect(sentryExceptionB.mechanism?.parentId, 0);

      expect(sentryExceptionA.throwable, throwableA);
      expect(sentryExceptionA.mechanism?.type, "generic");
      expect(sentryExceptionA.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionA.mechanism?.exceptionId, 0);
      expect(sentryExceptionA.mechanism?.parentId, isNull);
    });

    test('applies no grouping if there is no exception', () {
      final event = SentryEvent();
      final sut = fixture.getSut();

      final result = sut.apply(event, Hint());

      expect(result, event);
      expect(event.throwable, isNull);
      expect(event.exceptions, isNull);
    });

    test('applies no grouping if there is already a list of exceptions', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
              type: 'ExceptionA',
              value: 'ExceptionA',
              throwable: Exception('ExceptionA')),
          SentryException(
              type: 'ExceptionB',
              value: 'ExceptionB',
              throwable: Exception('ExceptionB')),
        ],
      );
      final sut = fixture.getSut();

      final result = sut.apply(event, Hint());

      final sentryExceptionA = result?.exceptions![0];
      final sentryExceptionB = result?.exceptions![1];

      expect(sentryExceptionA?.type, 'ExceptionA');
      expect(sentryExceptionB?.type, 'ExceptionB');
    });
  });
}

class Fixture {
  ExceptionGroupEventProcessor getSut() {
    return ExceptionGroupEventProcessor();
  }
}

class ExceptionA {
  ExceptionA(this.other);
  final ExceptionB? other;
}

class ExceptionB {
  ExceptionB(this.anotherOther);
  final ExceptionC? anotherOther;
}

class ExceptionC {
  // I am empty inside
}
