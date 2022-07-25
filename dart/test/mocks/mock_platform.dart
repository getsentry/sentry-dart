import 'package:sentry/src/platform/platform.dart';

import 'no_such_method_provider.dart';

class MockPlatform extends Platform with NoSuchMethodProvider {
  MockPlatform({String? os}) : operatingSystem = os ?? '';

  factory MockPlatform.android() {
    return MockPlatform(os: 'android');
  }

  factory MockPlatform.iOS() {
    return MockPlatform(os: 'ios');
  }

  @override
  String operatingSystem;
}
