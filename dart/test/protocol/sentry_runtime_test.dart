import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryRuntime = SentryRuntime(
    key: 'key',
    name: 'name',
    version: 'version',
    rawDescription: 'rawDescription',
    unknown: testUnknown,
  );

  final sentryRuntimeJson = <String, dynamic>{
    'name': 'name',
    'version': 'version',
    'raw_description': 'rawDescription',
  };
  sentryRuntimeJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryRuntime.toJson();

      expect(
        MapEquality().equals(sentryRuntimeJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryRuntime = SentryRuntime.fromJson(sentryRuntimeJson);
      final json = sentryRuntime.toJson();

      expect(
        MapEquality().equals(sentryRuntimeJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryRuntime;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryRuntime;

      final copy = data.copyWith(
        key: 'key1',
        name: 'name1',
        version: 'version1',
        rawDescription: 'rawDescription1',
      );

      expect('key1', copy.key);
      expect('name1', copy.name);
      expect('version1', copy.version);
      expect('rawDescription1', copy.rawDescription);
    });
  });
}
