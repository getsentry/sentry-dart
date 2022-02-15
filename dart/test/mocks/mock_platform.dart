import 'package:sentry/src/platform/platform.dart';

import 'no_such_method_provider.dart';

class MockPlatform extends Platform with NoSuchMethodProvider {
  const MockPlatform();

  @override
  String get operatingSystem => 'mock';

  @override
  String get operatingSystemVersion => 'mock';

  @override
  String get localHostname => 'mock';
}
