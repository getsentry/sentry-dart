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
    deviceAppHash: 'fixture-deviceAppHash'
  );

  final sentryAppJson = <String, dynamic>{
    'app_name': 'fixture-name',
    'app_version': 'fixture-version',
    'app_identifier': 'fixture-identifier',
    'app_build': 'fixture-build',
    'build_type': 'fixture-buildType',
    'app_start_time': testStartTime.toIso8601String(),
    'device_app_hash': 'fixture-deviceAppHash'
  };

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
}




