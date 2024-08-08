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
}
