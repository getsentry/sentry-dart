import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryStackTrace = SentryStackTrace(
    frames: [SentryStackFrame(absPath: 'abs')],
    registers: {'key': 'value'},
    lang: 'de',
    snapshot: true,
    unknown: testUnknown,
  );

  final sentryStackTraceJson = <String, dynamic>{
    'frames': [
      {'abs_path': 'abs'}
    ],
    'registers': {'key': 'value'},
    'lang': 'de',
    'snapshot': true,
  };
  sentryStackTraceJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryStackTrace.toJson();

      expect(
        DeepCollectionEquality().equals(sentryStackTraceJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryStackTrace = SentryStackTrace.fromJson(sentryStackTraceJson);
      final json = sentryStackTrace.toJson();

      expect(
        DeepCollectionEquality().equals(sentryStackTraceJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryStackTrace;

      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = sentryStackTrace;

      final frames = [SentryStackFrame(absPath: 'abs1')];
      final registers = {'key1': 'value1'};

      final copy = data.copyWith(
        frames: frames,
        registers: registers,
      );

      expect(
        ListEquality().equals(frames, copy.frames),
        true,
      );
      expect(
        MapEquality().equals(registers, copy.registers),
        true,
      );
    });
  });
}
