import 'dart:io' as io;

import 'platform.dart';

/// [Platform] implementation that delegates directly to `dart:io`.
class PlatformBase {
  const PlatformBase();

  OperatingSystem get operatingSystem {
    switch (io.Platform.operatingSystem) {
      case 'macos':
        return OperatingSystem.macos;
      case 'windows':
        return OperatingSystem.windows;
      case 'linux':
        return OperatingSystem.linux;
      case 'android':
        return OperatingSystem.android;
      case 'ios':
        return OperatingSystem.ios;
      case 'fuchsia':
        return OperatingSystem.fuchsia;
      default:
        return OperatingSystem.unknown;
    }
  }

  String? get operatingSystemVersion => io.Platform.operatingSystemVersion;

  String get localHostname => io.Platform.localHostname;

  bool get isWeb => false;
}
