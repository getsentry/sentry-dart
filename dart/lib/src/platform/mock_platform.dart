import 'platform.dart';

class MockPlatform extends Platform {
  @override
  late final bool isWeb;

  @override
  late final OperatingSystem operatingSystem;

  @override
  late final String? operatingSystemVersion;

  @override
  late final bool supportsNativeIntegration;

  MockPlatform(
      {OperatingSystem? operatingSystem,
      String? operatingSystemVersion,
      bool? isWeb,
      bool? supportsNativeIntegration}) {
    this.isWeb = isWeb ?? super.isWeb;
    this.operatingSystem = operatingSystem ?? super.operatingSystem;
    this.operatingSystemVersion =
        operatingSystemVersion ?? super.operatingSystemVersion;
    this.supportsNativeIntegration =
        supportsNativeIntegration ?? super.supportsNativeIntegration;
  }

  factory MockPlatform.android({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.android, isWeb: isWeb);
  }

  factory MockPlatform.iOS({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.ios, isWeb: isWeb);
  }

  factory MockPlatform.macOS({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.macos, isWeb: isWeb);
  }

  factory MockPlatform.linux({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.linux, isWeb: isWeb);
  }

  factory MockPlatform.windows({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.windows, isWeb: isWeb);
  }

  factory MockPlatform.fuchsia({bool isWeb = false}) {
    return MockPlatform(operatingSystem: OperatingSystem.fuchsia, isWeb: isWeb);
  }
}
