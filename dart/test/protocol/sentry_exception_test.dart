import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryException = SentryException(
    type: 'type',
    value: 'value',
    module: 'module',
    stackTrace: SentryStackTrace(frames: [SentryStackFrame(absPath: 'abs')]),
    mechanism: Mechanism(type: 'type'),
    threadId: 1,
    unknown: testUnknown,
  );

  final sentryExceptionJson = <String, dynamic>{
    'type': 'type',
    'value': 'value',
    'module': 'module',
    'stacktrace': {
      'frames': [
        {'abs_path': 'abs'}
      ]
    },
    'mechanism': {'type': 'type'},
    'thread_id': 1,
  };
  sentryExceptionJson.addAll(testUnknown);

  group('json', () {
    test('fromJson', () {
      final sentryException = SentryException.fromJson(sentryExceptionJson);
      final json = sentryException.toJson();

      expect(
        DeepCollectionEquality().equals(sentryExceptionJson, json),
        true,
      );
    });

    test('should serialize stacktrace', () {
      final mechanism = Mechanism(
        type: 'mechanism-example',
        description: 'a mechanism',
        handled: true,
        synthetic: false,
        helpLink: 'https://help.com',
        data: {'polyfill': 'bluebird'},
        meta: {
          'signal': {
            'number': 10,
            'code': 0,
            'name': 'SIGBUS',
            'code_name': 'BUS_NOOP'
          }
        },
      );
      final stacktrace = SentryStackTrace(frames: [
        SentryStackFrame(
          absPath: 'frame-path',
          fileName: 'example.dart',
          function: 'parse',
          module: 'example-module',
          lineNo: 1,
          colNo: 2,
          contextLine: 'context-line example',
          inApp: true,
          package: 'example-package',
          native: false,
          platform: 'dart',
          rawFunction: 'example-rawFunction',
          framesOmitted: [1, 2, 3],
        ),
      ]);

      final sentryException = SentryException(
        type: 'StateError',
        value: 'Bad state: error',
        module: 'example.module',
        stackTrace: stacktrace,
        mechanism: mechanism,
        threadId: 123456,
      );

      final serialized = sentryException.toJson();

      expect(serialized['type'], 'StateError');
      expect(serialized['value'], 'Bad state: error');
      expect(serialized['module'], 'example.module');
      expect(serialized['thread_id'], 123456);
      expect(serialized['mechanism']['type'], 'mechanism-example');
      expect(serialized['mechanism']['description'], 'a mechanism');
      expect(serialized['mechanism']['handled'], true);
      expect(serialized['mechanism']['synthetic'], false);
      expect(serialized['mechanism']['help_link'], 'https://help.com');
      expect(serialized['mechanism']['data'], {'polyfill': 'bluebird'});
      expect(serialized['mechanism']['meta'], {
        'signal': {
          'number': 10,
          'code': 0,
          'name': 'SIGBUS',
          'code_name': 'BUS_NOOP'
        }
      });

      final serializedFrame = serialized['stacktrace']['frames'].first;
      expect(serializedFrame['abs_path'], 'frame-path');
      expect(serializedFrame['filename'], 'example.dart');
      expect(serializedFrame['function'], 'parse');
      expect(serializedFrame['module'], 'example-module');
      expect(serializedFrame['lineno'], 1);
      expect(serializedFrame['colno'], 2);
      expect(serializedFrame['context_line'], 'context-line example');
      expect(serializedFrame['in_app'], true);
      expect(serializedFrame['package'], 'example-package');
      expect(serializedFrame['native'], false);
      expect(serializedFrame['platform'], 'dart');
      expect(serializedFrame['raw_function'], 'example-rawFunction');
      expect(serializedFrame['frames_omitted'], [1, 2, 3]);
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryException;

      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = sentryException;

      final stackTrace =
          SentryStackTrace(frames: [SentryStackFrame(absPath: 'abs1')]);
      final mechanism = Mechanism(type: 'type1');

      final copy = data.copyWith(
        type: 'type1',
        value: 'value1',
        module: 'module1',
        stackTrace: stackTrace,
        mechanism: mechanism,
        threadId: 2,
      );

      expect('type1', copy.type);
      expect('value1', copy.value);
      expect('module1', copy.module);
      expect(2, copy.threadId);
      expect(mechanism.toJson(), copy.mechanism!.toJson());
      expect(stackTrace.toJson(), copy.stackTrace!.toJson());
    });
  });

  group('flatten', () {
    test('flatten exception without nested exceptions', () {
      final origin = sentryException.copyWith(
        value: 'origin',
      );

      final flattened = origin.flatten();

      expect(flattened.length, 1);
      expect(flattened.first.value, 'origin');

      expect(flattened.first.mechanism?.source, isNull);
      expect(flattened.first.mechanism?.exceptionId, 0);
      expect(flattened.first.mechanism?.parentId, null);
    });

    test('flatten exception with nested chained exceptions', () {
      final origin = sentryException.copyWith(
        value: 'origin',
      );
      final originChild = sentryException.copyWith(
        value: 'originChild',
      );
      origin.addException(originChild);
      final originChildChild = sentryException.copyWith(
        value: 'originChildChild',
      );
      originChild.addException(originChildChild);

      final flattened = origin.flatten();

      expect(flattened.length, 3);

      expect(flattened[0].value, 'origin');
      expect(flattened[0].mechanism?.isExceptionGroup, isNull);
      expect(flattened[0].mechanism?.source, isNull);
      expect(flattened[0].mechanism?.exceptionId, 0);
      expect(flattened[0].mechanism?.parentId, null);

      expect(flattened[1].value, 'originChild');
      expect(flattened[1].mechanism?.source, isNull);
      expect(flattened[1].mechanism?.exceptionId, 1);
      expect(flattened[1].mechanism?.parentId, 0);

      expect(flattened[2].value, 'originChildChild');
      expect(flattened[2].mechanism?.source, isNull);
      expect(flattened[2].mechanism?.exceptionId, 2);
      expect(flattened[2].mechanism?.parentId, 1);
    });

    test('flatten exception with nested parallel exceptions', () {
      final origin = sentryException.copyWith(
        value: 'origin',
      );
      final originChild = sentryException.copyWith(
        value: 'originChild',
      );
      origin.addException(originChild);
      final originChild2 = sentryException.copyWith(
        value: 'originChild2',
      );
      origin.addException(originChild2);

      final flattened = origin.flatten();

      expect(flattened.length, 3);

      expect(flattened[0].value, 'origin');
      expect(flattened[0].mechanism?.isExceptionGroup, true);
      expect(flattened[0].mechanism?.source, isNull);
      expect(flattened[0].mechanism?.exceptionId, 0);
      expect(flattened[0].mechanism?.parentId, null);

      expect(flattened[1].value, 'originChild');
      expect(flattened[1].mechanism?.source, isNull);
      expect(flattened[1].mechanism?.exceptionId, 1);
      expect(flattened[1].mechanism?.parentId, 0);

      expect(flattened[2].value, 'originChild2');
      expect(flattened[2].mechanism?.source, isNull);
      expect(flattened[2].mechanism?.exceptionId, 2);
      expect(flattened[2].mechanism?.parentId, 0);
    });

    test('flatten rfc example', () {
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

      final exceptionGroupNested = sentryException.copyWith(
        value: 'ExceptionGroup',
      );
      final runtimeError = sentryException.copyWith(
        value: 'RuntimeError',
        mechanism: sentryException.mechanism?.copyWith(source: '__source__'),
      );
      exceptionGroupNested.addException(runtimeError);
      final valueError = sentryException.copyWith(
        value: 'ValueError',
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[0]'),
      );
      exceptionGroupNested.addException(valueError);

      final exceptionGroupImports = sentryException.copyWith(
        value: 'ExceptionGroup',
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[1]'),
      );
      exceptionGroupNested.addException(exceptionGroupImports);

      final importError = sentryException.copyWith(
        value: 'ImportError',
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[0]'),
      );
      exceptionGroupImports.addException(importError);
      final moduleNotFoundError = sentryException.copyWith(
        value: 'ModuleNotFoundError',
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[1]'),
      );
      exceptionGroupImports.addException(moduleNotFoundError);

      final typeError = sentryException.copyWith(
        value: 'TypeError',
        mechanism: sentryException.mechanism?.copyWith(source: 'exceptions[2]'),
      );
      exceptionGroupNested.addException(typeError);

      final flattened =
          exceptionGroupNested.flatten().reversed.toList(growable: false);

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
