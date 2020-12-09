import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final app = _getApp();

    final copy = app.copyWith();

    expect(
      MapEquality().equals(app.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final app = _getApp();

    final startTime = DateTime.now();

    final copy = app.copyWith(
      name: 'name1',
      version: 'version1',
      identifier: 'identifier1',
      build: 'build1',
      buildType: 'buildType1',
      startTime: startTime,
      deviceAppHash: 'hash1',
    );

    expect('name1', copy.name);
    expect('version1', copy.version);
    expect('identifier1', copy.identifier);
    expect('build1', copy.build);
    expect('buildType1', copy.buildType);
    expect(startTime, copy.startTime);
    expect('hash1', copy.deviceAppHash);
  });
}

App _getApp({DateTime startTime}) => App(
      name: 'name',
      version: 'version',
      identifier: 'identifier',
      build: 'build',
      buildType: 'buildType',
      startTime: startTime ?? DateTime.now(),
      deviceAppHash: 'hash',
    );
