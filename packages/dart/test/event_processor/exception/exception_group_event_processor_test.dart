import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'package:sentry/src/event_processor/exception/exception_group_event_processor.dart';

import '../../test_utils.dart';

void main() {
  group(ExceptionGroupEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('does not group exceptions if groupExceptions is false', () {
      final throwableA = Exception('ExceptionA');
      final exceptionA = SentryException(
        type: 'ExceptionA',
        value: 'ExceptionA',
        throwable: throwableA,
        mechanism: Mechanism(type: 'foo'),
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

      final sut = fixture.getSut(groupExceptions: false);
      event = (sut.apply(event, Hint()))!;

      final sentryExceptionA = event.exceptions![0];
      final sentryExceptionB = event.exceptions![1];

      expect(sentryExceptionB.throwable, throwableB);
      expect(sentryExceptionB.mechanism?.type, isNull);
      expect(sentryExceptionB.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionB.mechanism?.exceptionId, isNull);
      expect(sentryExceptionB.mechanism?.parentId, isNull);

      expect(sentryExceptionA.throwable, throwableA);
      expect(sentryExceptionA.mechanism?.type, "foo");
      expect(sentryExceptionA.mechanism?.isExceptionGroup, isNull);
      expect(sentryExceptionA.mechanism?.exceptionId, isNull);
      expect(sentryExceptionA.mechanism?.parentId, isNull);
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

      final sut = fixture.getSut(groupExceptions: true);
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
      expect(sentryExceptionA.mechanism?.isExceptionGroup, isTrue);
      expect(sentryExceptionA.mechanism?.exceptionId, 0);
      expect(sentryExceptionA.mechanism?.parentId, isNull);
    });

    test('applies no grouping if there is no exception', () {
      final event = SentryEvent();
      final sut = fixture.getSut(groupExceptions: true);

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
      final sut = fixture.getSut(groupExceptions: true);

      final result = sut.apply(event, Hint());

      final sentryExceptionA = result?.exceptions![0];
      final sentryExceptionB = result?.exceptions![1];

      expect(sentryExceptionA?.type, 'ExceptionA');
      expect(sentryExceptionB?.type, 'ExceptionB');
    });
  });

  group('flatten', () {
    late Fixture fixture;

    SentryException buildException(String value, {String? source}) =>
        SentryException(
          type: 'type',
          value: value,
          module: 'module',
          stackTrace:
              SentryStackTrace(frames: [SentryStackFrame(absPath: 'abs')]),
          mechanism: Mechanism(type: 'type', source: source),
          threadId: 1,
        );

    setUp(() {
      fixture = Fixture();
    });

    test('will flatten exception with nested chained exceptions', () {
      final origin = buildException('origin');
      final originChild = buildException('originChild');
      origin.addException(originChild);

      final originChildChild = buildException('originChildChild');
      originChild.addException(originChildChild);

      final sut = fixture.getSut(groupExceptions: true);
      var event = SentryEvent(exceptions: [origin]);
      event = sut.apply(event, Hint())!;
      final flattened = event.exceptions ?? [];

      expect(flattened.length, 3);

      expect(flattened[2].value, 'origin');
      expect(flattened[2].mechanism?.isExceptionGroup, isTrue);
      expect(flattened[2].mechanism?.source, isNull);
      expect(flattened[2].mechanism?.exceptionId, 0);
      expect(flattened[2].mechanism?.parentId, null);

      expect(flattened[1].value, 'originChild');
      expect(flattened[1].mechanism?.isExceptionGroup, isTrue);
      expect(flattened[1].mechanism?.source, isNull);
      expect(flattened[1].mechanism?.exceptionId, 1);
      expect(flattened[1].mechanism?.parentId, 0);

      expect(flattened[0].value, 'originChildChild');
      expect(flattened[0].mechanism?.isExceptionGroup, isNull);
      expect(flattened[0].mechanism?.source, isNull);
      expect(flattened[0].mechanism?.exceptionId, 2);
      expect(flattened[0].mechanism?.parentId, 1);
    });

    test('will flatten exception with nested parallel exceptions', () {
      final origin = buildException('origin');
      final originChild = buildException('originChild');
      origin.addException(originChild);
      final originChild2 = buildException('originChild2');
      origin.addException(originChild2);

      final sut = fixture.getSut(groupExceptions: true);
      var event = SentryEvent(exceptions: [origin]);
      event = sut.apply(event, Hint())!;
      final flattened = event.exceptions ?? [];

      expect(flattened.length, 3);

      expect(flattened[2].value, 'origin');
      expect(flattened[2].mechanism?.isExceptionGroup, true);
      expect(flattened[2].mechanism?.source, isNull);
      expect(flattened[2].mechanism?.exceptionId, 0);
      expect(flattened[2].mechanism?.parentId, null);

      expect(flattened[1].value, 'originChild');
      expect(flattened[1].mechanism?.source, isNull);
      expect(flattened[1].mechanism?.exceptionId, 1);
      expect(flattened[1].mechanism?.parentId, 0);

      expect(flattened[0].value, 'originChild2');
      expect(flattened[0].mechanism?.source, isNull);
      expect(flattened[0].mechanism?.exceptionId, 2);
      expect(flattened[0].mechanism?.parentId, 0);
    });

    test('will flatten rfc example', () {
      // try:
      //   raise RuntimeError("something")
      // except:
      //   raise ExceptionGroup("nested",
      //     [
      //       ValueError(654),
      //       ExceptionGroup("imports",
      //         [
      //           ImportError("no_such_module"),
      //           ModuleNotFoundError("another_module"),
      //         ]
      //       ),
      //       TypeError("int"),
      //     ]
      //   )

      // https://github.com/getsentry/rfcs/blob/main/text/0079-exception-groups.md#example-event
      // In the example, the runtime error is inserted as the first exception in the outer exception group.

      final exceptionGroupNested = buildException('ExceptionGroup');
      final runtimeError = buildException('RuntimeError', source: '__source__');
      exceptionGroupNested.addException(runtimeError);
      final valueError = buildException('ValueError', source: 'exceptions[0]');
      exceptionGroupNested.addException(valueError);

      final exceptionGroupImports =
          buildException('ExceptionGroup', source: 'exceptions[1]');
      exceptionGroupNested.addException(exceptionGroupImports);

      final importError =
          buildException('ImportError', source: 'exceptions[0]');
      exceptionGroupImports.addException(importError);

      final moduleNotFoundError =
          buildException('ModuleNotFoundError', source: 'exceptions[1]');
      exceptionGroupImports.addException(moduleNotFoundError);

      final typeError = buildException('TypeError', source: 'exceptions[2]');
      exceptionGroupNested.addException(typeError);

      final sut = fixture.getSut(groupExceptions: true);
      var event = SentryEvent(exceptions: [exceptionGroupNested]);
      event = sut.apply(event, Hint())!;
      final flattened = event.exceptions ?? [];

      expect(flattened.length, 7);

      // {
      //   "exception": {
      //     "values": [
      //       {
      //         "type": "TypeError",
      //         "value": "int",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "exceptions[2]",
      //           "exception_id": 6,
      //           "parent_id": 0
      //         }
      //       },
      //       {
      //         "type": "ModuleNotFoundError",
      //         "value": "another_module",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "exceptions[1]",
      //           "exception_id": 5,
      //           "parent_id": 3
      //         }
      //       },
      //       {
      //         "type": "ImportError",
      //         "value": "no_such_module",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "exceptions[0]",
      //           "exception_id": 4,
      //           "parent_id": 3
      //         }
      //       },
      //       {
      //         "type": "ExceptionGroup",
      //         "value": "imports",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "exceptions[1]",
      //           "is_exception_group": true,
      //           "exception_id": 3,
      //           "parent_id": 0
      //         }
      //       },
      //       {
      //         "type": "ValueError",
      //         "value": "654",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "exceptions[0]",
      //           "exception_id": 2,
      //           "parent_id": 0
      //         }
      //       },
      //       {
      //         "type": "RuntimeError",
      //         "value": "something",
      //         "mechanism": {
      //           "type": "chained",
      //           "source": "__context__",
      //           "exception_id": 1,
      //           "parent_id": 0
      //         }
      //       },
      //       {
      //         "type": "ExceptionGroup",
      //         "value": "nested",
      //         "mechanism": {
      //           "type": "exceptionhook",
      //           "handled": false,
      //           "is_exception_group": true,
      //           "exception_id": 0
      //         }
      //       },
      //     ]
      //   }
      // }

      expect(flattened[0].value, 'TypeError');
      expect(flattened[0].mechanism?.source, 'exceptions[2]');
      expect(flattened[0].mechanism?.exceptionId, 6);
      expect(flattened[0].mechanism?.parentId, 0);
      expect(flattened[0].mechanism?.type, 'chained');

      expect(flattened[1].value, 'ModuleNotFoundError');
      expect(flattened[1].mechanism?.source, 'exceptions[1]');
      expect(flattened[1].mechanism?.exceptionId, 5);
      expect(flattened[1].mechanism?.parentId, 3);
      expect(flattened[1].mechanism?.type, 'chained');

      expect(flattened[2].value, 'ImportError');
      expect(flattened[2].mechanism?.source, 'exceptions[0]');
      expect(flattened[2].mechanism?.exceptionId, 4);
      expect(flattened[2].mechanism?.parentId, 3);
      expect(flattened[2].mechanism?.type, 'chained');

      expect(flattened[3].value, 'ExceptionGroup');
      expect(flattened[3].mechanism?.source, 'exceptions[1]');
      expect(flattened[3].mechanism?.isExceptionGroup, true);
      expect(flattened[3].mechanism?.exceptionId, 3);
      expect(flattened[3].mechanism?.parentId, 0);
      expect(flattened[3].mechanism?.type, 'chained');

      expect(flattened[4].value, 'ValueError');
      expect(flattened[4].mechanism?.source, 'exceptions[0]');
      expect(flattened[4].mechanism?.exceptionId, 2);
      expect(flattened[4].mechanism?.parentId, 0);
      expect(flattened[4].mechanism?.type, 'chained');

      expect(flattened[5].value, 'RuntimeError');
      expect(flattened[5].mechanism?.exceptionId, 1);
      expect(flattened[5].mechanism?.parentId, 0);
      expect(flattened[5].mechanism?.type, 'chained');

      expect(flattened[6].value, 'ExceptionGroup');
      expect(flattened[6].mechanism?.isExceptionGroup, true);
      expect(flattened[6].mechanism?.exceptionId, 0);
      expect(flattened[6].mechanism?.parentId, isNull);
      expect(
          flattened[6].mechanism?.type, exceptionGroupNested.mechanism?.type);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  ExceptionGroupEventProcessor getSut({required bool groupExceptions}) {
    options.groupExceptions = groupExceptions;
    return ExceptionGroupEventProcessor(options);
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
