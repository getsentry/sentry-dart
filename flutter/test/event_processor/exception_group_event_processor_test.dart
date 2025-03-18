import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/event_processor/exception_group_event_processor.dart';

void main() {
  group(ExceptionGroupEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('applies grouping to exception cause exceptions', () {
      final exceptionC = ExceptionC(); // Original
      final exceptionB = ExceptionB(exceptionC);
      final exceptionA = ExceptionA(exceptionB);

      // Would be the result of RecursiveExceptionCauseExtractor
      final causes = [
        ExceptionCause(exceptionA, null, source: "anotherOther"),
        ExceptionCause(exceptionB, null, source: "other"),
        ExceptionCause(exceptionC, null, source: null),
      ];

      final sentryExceptions = causes.map((e) {
        return SentryException(
          type: 'fixture-original-type',
          value: 'fixture-original-value',
          throwable: e.exception,
          mechanism: Mechanism(type: "fixture-type", source: e.source),
        );
      }).toList();
      var event = SentryEvent(exceptions: sentryExceptions);

      final sut = fixture.getSut();
      event = (sut.apply(event, Hint()))!;

      final sentryExceptionC = event.exceptions![0];
      expect(sentryExceptionC.mechanism?.type, "chained");
      expect(sentryExceptionC.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionC.mechanism?.exceptionId, 2);
      expect(sentryExceptionC.mechanism?.parentId, 1);

      final sentryExceptionB = event.exceptions![1];
      expect(sentryExceptionB.mechanism?.type, "chained");
      expect(sentryExceptionB.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionB.mechanism?.exceptionId, 1);
      expect(sentryExceptionB.mechanism?.parentId, 0);

      final sentryExceptionA = event.exceptions![2];
      expect(sentryExceptionA.mechanism?.type, "fixture-type");
      expect(sentryExceptionA.mechanism?.isExceptionGroup, true);
      expect(sentryExceptionA.mechanism?.exceptionId, 0);
      expect(sentryExceptionA.mechanism?.parentId, isNull);
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
