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
}
