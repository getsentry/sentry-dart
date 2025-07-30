import '_io_platform.dart' if (dart.library.js_interop) '_web_platform.dart'
    as impl;

class Platform extends impl.PlatformBase {
  const Platform();

  bool get isLinux => operatingSystem == OperatingSystem.linux;

  bool get isMacOS => operatingSystem == OperatingSystem.macos;

  bool get isWindows => operatingSystem == OperatingSystem.windows;

  bool get isAndroid => operatingSystem == OperatingSystem.android;

  bool get isIOS => operatingSystem == OperatingSystem.ios;

  bool get isFuchsia => operatingSystem == OperatingSystem.fuchsia;

  bool get supportsNativeIntegration => !isFuchsia;
}

enum OperatingSystem {
  android,
  fuchsia,
  ios,
  linux,
  macos,
  windows,
  unknown,
}
