import 'package:sentry/src/platform/platform.dart';

class MockPlatform extends Platform {
  const MockPlatform();

  @override
  String get operatingSystem => 'mock';

  @override
  String get operatingSystemVersion => 'mock';

  @override
  String get localHostname => 'mock';
}
