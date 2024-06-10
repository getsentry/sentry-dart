@TestOn('vm')
library file_test;

import 'dart:io';

import 'package:sentry/src/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  group('sdkVersion', () {
    test('matches that of pubspec.yaml', () {
      final dynamic pubspec =
          yaml.loadYaml(File('pubspec.yaml').readAsStringSync());
      expect(sdkVersion, pubspec['version']);
    });
  });
}
