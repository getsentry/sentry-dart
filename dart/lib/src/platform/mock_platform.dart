import 'platform.dart';

class MockPlatform extends Platform {
  @override
  late final bool isWeb;

  @override
  late final OperatingSystem operatingSystem;

  @override
  late final String? operatingSystemVersion;

  MockPlatform({
    OperatingSystem? operatingSystem,
    String? operatingSystemVersion,
    bool? isWeb,
  }) {
    this.isWeb = isWeb ?? super.isWeb;
    this.operatingSystem = operatingSystem ?? super.operatingSystem;
    this.operatingSystemVersion = operatingSystemVersion ?? super.operatingSystemVersion;
  }

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
