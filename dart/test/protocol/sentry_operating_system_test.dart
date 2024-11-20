import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryOperatingSystem = SentryOperatingSystem(
    name: 'fixture-name',
    version: 'fixture-version',
    build: 'fixture-build',
    kernelVersion: 'fixture-kernelVersion',
    rooted: true,
    rawDescription: 'fixture-rawDescription',
    unknown: testUnknown,
  );

  final sentryOperatingSystemJson = <String, dynamic>{
    'name': 'fixture-name',
    'version': 'fixture-version',
    'build': 'fixture-build',
    'kernel_version': 'fixture-kernelVersion',
    'rooted': true,
    'raw_description': 'fixture-rawDescription'
  };
  sentryOperatingSystemJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryOperatingSystem.toJson();

      expect(
        MapEquality().equals(sentryOperatingSystemJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryOperatingSystem =
          SentryOperatingSystem.fromJson(sentryOperatingSystemJson);
      final json = sentryOperatingSystem.toJson();

      expect(
        MapEquality().equals(sentryOperatingSystemJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryOperatingSystem;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryOperatingSystem;

      final copy = data.copyWith(
        name: 'name1',
        version: 'version1',
        build: 'build1',
        kernelVersion: 'kernelVersion1',
        rooted: true,
      );

      expect('name1', copy.name);
      expect('version1', copy.version);
      expect('build1', copy.build);
      expect('kernelVersion1', copy.kernelVersion);
      expect(true, copy.rooted);
    });
  });
}
