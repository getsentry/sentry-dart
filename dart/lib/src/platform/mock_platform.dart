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
    return MockPlatform(operatingSystem: OperatingSystem.android, isWeb: false);
  }

  factory MockPlatform.iOS() {
    return MockPlatform(operatingSystem: OperatingSystem.ios, isWeb: false);
  }

  factory MockPlatform.macOS() {
    return MockPlatform(operatingSystem: OperatingSystem.macos, isWeb: false);
  }

  factory MockPlatform.linux() {
    return MockPlatform(operatingSystem: OperatingSystem.linux, isWeb: false);
  }

  factory MockPlatform.windows() {
    return MockPlatform(operatingSystem: OperatingSystem.windows, isWeb: false);
  }
}
