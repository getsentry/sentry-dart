import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final testStartTime = DateTime.fromMicrosecondsSinceEpoch(0);

  final sentryApp = SentryApp(
      name: 'fixture-name',
      version: 'fixture-version',
      identifier: 'fixture-identifier',
      build: 'fixture-build',
      buildType: 'fixture-buildType',
      startTime: testStartTime,
      deviceAppHash: 'fixture-deviceAppHash',
      inForeground: true,
      screen: 'fixture-screen');

  final sentryAppJson = <String, dynamic>{
    'app_name': 'fixture-name',
    'app_version': 'fixture-version',
    'app_identifier': 'fixture-identifier',
    'app_build': 'fixture-build',
    'build_type': 'fixture-buildType',
    'app_start_time': testStartTime.toIso8601String(),
    'device_app_hash': 'fixture-deviceAppHash',
    'in_foreground': true,
    'screen': 'fixture-screen',
  };

  group('json', () {
    test('toJson', () {
      final json = sentryApp.toJson();

      expect(
        MapEquality().equals(sentryAppJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryApp = SentryApp.fromJson(sentryAppJson);
      final json = sentryApp.toJson();

      expect(
        MapEquality().equals(sentryAppJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryApp;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryApp;

      final startTime = DateTime.now();

      final copy = data.copyWith(
        name: 'name1',
        version: 'version1',
        identifier: 'identifier1',
        build: 'build1',
        buildType: 'buildType1',
        startTime: startTime,
        deviceAppHash: 'hash1',
        inForeground: true,
        screen: 'screen1',
      );

      expect('name1', copy.name);
      expect('version1', copy.version);
      expect('identifier1', copy.identifier);
      expect('build1', copy.build);
      expect('buildType1', copy.buildType);
      expect(startTime, copy.startTime);
      expect('hash1', copy.deviceAppHash);
      expect(true, copy.inForeground);
      expect('screen1', copy.screen);
    });
  });
}
