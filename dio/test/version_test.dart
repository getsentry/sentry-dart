@TestOn('vm')
library dio_test;

import 'dart:io';

import 'package:sentry_dio/src/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  test(
    'sdkVersion matches that of pubspec.yaml',
    () {
      final dynamic pubspec =
          yaml.loadYaml(File('pubspec.yaml').readAsStringSync());
      expect(sdkVersion, pubspec['version']);
    },
  );
}
