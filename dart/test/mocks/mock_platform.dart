import 'dart:typed_data';

import 'package:sentry/src/platform/platform.dart';

import 'no_such_method_provider.dart';

class MockPlatform extends Platform with NoSuchMethodProvider {
  MockPlatform({String? os, Endian? endian})
      : operatingSystem = os ?? '',
        endian = endian ?? Endian.host;

  factory MockPlatform.android() {
    return MockPlatform(os: 'android');
  }

  factory MockPlatform.iOS() {
    return MockPlatform(os: 'ios');
  }

  factory MockPlatform.macOS() {
    return MockPlatform(os: 'macos');
  }

  factory MockPlatform.linux() {
    return MockPlatform(os: 'linux');
  }

  factory MockPlatform.windows() {
    return MockPlatform(os: 'windows');
  }

  @override
  final String operatingSystem;

  @override
  final Endian endian;

  @override
  String toString() => operatingSystem;
}
