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
}
