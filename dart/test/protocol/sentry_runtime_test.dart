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
}
