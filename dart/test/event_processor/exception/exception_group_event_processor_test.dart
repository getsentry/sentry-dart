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

  group('flatten', () {
    late Fixture fixture;

    final sentryException = SentryException(
      type: 'type',
      value: 'value',
      module: 'module',
      stackTrace: SentryStackTrace(frames: [SentryStackFrame(absPath: 'abs')]),
      mechanism: Mechanism(type: 'type'),
      threadId: 1,
    );

    setUp(() {
      fixture = Fixture();
    });

    test('will flatten exception with nested chained exceptions', () {
      // ignore: deprecated_member_use_from_same_package
      final origin = sentryException.copyWith(
        value: 'origin',
      );
      // ignore: deprecated_member_use_from_same_package
      final originChild = sentryException.copyWith(
        value: 'originChild',
      );
      origin.addException(originChild);

      // ignore: deprecated_member_use_from_same_package
      final originChildChild = sentryException.copyWith(
        value: 'originChildChild',
      );
      originChild.addException(originChildChild);

      final sut = fixture.getSut();
      var event = SentryEvent(exceptions: [origin]);
      event = sut.apply(event, Hint())!;
      final flattened = event.exceptions ?? [];

      expect(flattened.length, 3);

      expect(flattened[2].value, 'origin');
      expect(flattened[2].mechanism?.isExceptionGroup, isNull);
      expect(flattened[2].mechanism?.source, isNull);
      expect(flattened[2].mechanism?.exceptionId, 0);
      expect(flattened[2].mechanism?.parentId, null);

      expect(flattened[1].value, 'originChild');
      expect(flattened[1].mechanism?.source, isNull);
      expect(flattened[1].mechanism?.exceptionId, 1);
      expect(flattened[1].mechanism?.parentId, 0);

      expect(flattened[0].value, 'originChildChild');
      expect(flattened[0].mechanism?.source, isNull);
      expect(flattened[0].mechanism?.exceptionId, 2);
      expect(flattened[0].mechanism?.parentId, 1);
    });

    test('will flatten exception with nested parallel exceptions', () {
      // ignore: deprecated_member_use_from_same_package
      final origin = sentryException.copyWith(
        value: 'origin',
      );
      // ignore: deprecated_member_use_from_same_package
      final originChild = sentryException.copyWith(
        value: 'originChild',
      );
      origin.addException(originChild);
      // ignore: deprecated_member_use_from_same_package
      final originChild2 = sentryException.copyWith(
        value: 'originChild2',
      );
      origin.addException(originChild2);

      final sut = fixture.getSut();
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

      // ignore: deprecated_member_use_from_same_package
      final exceptionGroupNested = sentryException.copyWith(
        value: 'ExceptionGroup',
      );
      // ignore: deprecated_member_use_from_same_package
      final runtimeError = sentryException.copyWith(
        value: 'RuntimeError',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: '__source__'),
      );
      exceptionGroupNested.addException(runtimeError);
      // ignore: deprecated_member_use_from_same_package
      final valueError = sentryException.copyWith(
        value: 'ValueError',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[0]'),
      );
      exceptionGroupNested.addException(valueError);

      // ignore: deprecated_member_use_from_same_package
      final exceptionGroupImports = sentryException.copyWith(
        value: 'ExceptionGroup',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[1]'),
      );
      exceptionGroupNested.addException(exceptionGroupImports);

      // ignore: deprecated_member_use_from_same_package
      final importError = sentryException.copyWith(
        value: 'ImportError',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[0]'),
      );
      exceptionGroupImports.addException(importError);

      // ignore: deprecated_member_use_from_same_package
      final moduleNotFoundError = sentryException.copyWith(
        value: 'ModuleNotFoundError',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[1]'),
      );
      exceptionGroupImports.addException(moduleNotFoundError);

      // ignore: deprecated_member_use_from_same_package
      final typeError = sentryException.copyWith(
        value: 'TypeError',
        // ignore: deprecated_member_use_from_same_package
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[2]'),
      );
      exceptionGroupNested.addException(typeError);

      final sut = fixture.getSut();
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
