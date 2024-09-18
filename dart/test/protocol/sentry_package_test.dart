import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryPackage = SentryPackage(
    'name',
    'version',
    unknown: testUnknown,
  );

  final sentryPackageJson = <String, dynamic>{
    'name': 'name',
    'version': 'version',
  };
  sentryPackageJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryPackage.toJson();

      expect(
        MapEquality().equals(sentryPackageJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryPackage = SdkVersion.fromJson(sentryPackageJson);
      final json = sentryPackage.toJson();

      expect(
        MapEquality().equals(sentryPackageJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryPackage;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = sentryPackage;

      final copy = data.copyWith(
        name: 'name1',
        version: 'version1',
      );

      expect('name1', copy.name);
      expect('version1', copy.version);
    });
  });
}
