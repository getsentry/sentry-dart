@TestOn('vm')
library;

import 'dart:io';

import 'package:sentry_sqflite/src/version.dart';
import 'package:flutter_test/flutter_test.dart';
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
