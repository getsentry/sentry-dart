import 'package:platform/platform.dart';

extension MockPlatform on FakePlatform {
  static Platform android() {
    return FakePlatform(operatingSystem: 'android');
  }

  static Platform iOS() {
    return FakePlatform(operatingSystem: 'ios');
  }

  static Platform macOS() {
    return FakePlatform(operatingSystem: 'macos');
  }

  static Platform linux() {
    return FakePlatform(operatingSystem: 'linux');
  }

  static Platform windows() {
    return FakePlatform(operatingSystem: 'windows');
  }
}
