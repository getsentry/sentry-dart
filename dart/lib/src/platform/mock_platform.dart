import 'platform.dart';

class MockPlatform extends Platform {
  @override
  final bool isWeb;

  @override
  final String localHostname;

  @override
  final OperatingSystem operatingSystem;

  @override
  final String operatingSystemVersion;

  MockPlatform({
    this.operatingSystem = OperatingSystem.unknown,
    this.operatingSystemVersion = '',
    this.isWeb = false,
    this.localHostname = '',
  });

  factory MockPlatform.android() {
    return MockPlatform(operatingSystem: OperatingSystem.android);
  }

  factory MockPlatform.iOS() {
    return MockPlatform(operatingSystem: OperatingSystem.ios);
  }

  factory MockPlatform.macOS() {
    return MockPlatform(operatingSystem: OperatingSystem.macos);
  }

  factory MockPlatform.linux() {
    return MockPlatform(operatingSystem: OperatingSystem.linux);
  }

  factory MockPlatform.windows() {
    return MockPlatform(operatingSystem: OperatingSystem.windows);
  }
}
