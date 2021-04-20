import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  
  final sentryOperatingSystem = SentryOperatingSystem(
    name: 'fixture-name',
    version: 'fixture-version',
    build: 'fixture-build',
    kernelVersion: 'fixture-kernelVersion',
    rooted: true,
    rawDescription: 'fixture-rawDescription'
  );

  final sentryOperatingSystemJson = <String, dynamic>{
    'name': 'fixture-name',
    'version': 'fixture-version',
    'build': 'fixture-build',
    'kernel_version': 'fixture-kernelVersion',
    'rooted': true,
    'raw_description': 'fixture-rawDescription'
  };

  group('json', () {
    test('toJson', () {
      final json = sentryOperatingSystem.toJson();

      expect(
        MapEquality().equals(sentryOperatingSystemJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryOperatingSystem = SentryOperatingSystem.fromJson(sentryOperatingSystemJson);
      final json = sentryOperatingSystem.toJson();

      expect(
        MapEquality().equals(sentryOperatingSystemJson, json),
        true,
      );
    });
  });
}
