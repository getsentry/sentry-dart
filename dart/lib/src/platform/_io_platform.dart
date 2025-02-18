import 'dart:io' as io;

import 'platform.dart';

const Platform currentPlatform = IOPlatform();

/// [Platform] implementation that delegates directly to `dart:io`.
class IOPlatform extends Platform {
  const IOPlatform();

  @override
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

  @override
  String? get operatingSystemVersion => io.Platform.operatingSystemVersion;

  @override
  String get localHostname => io.Platform.localHostname;

  @override
  bool get isWeb => false;
}
