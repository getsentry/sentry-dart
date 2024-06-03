// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library dart_test;

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
