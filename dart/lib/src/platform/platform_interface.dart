abstract class Platform {
  const Platform();

  bool get isWeb;

  bool get isLinux => operatingSystem == OperatingSystem.linux;

  bool get isMacOS => operatingSystem == OperatingSystem.macos;

  bool get isWindows => operatingSystem == OperatingSystem.windows;

  bool get isAndroid => operatingSystem == OperatingSystem.android;

  bool get isIOS => operatingSystem == OperatingSystem.ios;

  bool get isFuchsia => operatingSystem == OperatingSystem.fuchsia;

  /// A string (`linux`, `macos`, `windows`, `android`, `ios`, or `fuchsia`)
  /// representing the operating system.
  OperatingSystem get operatingSystem;

  /// A string representing the version of the operating system or platform.
  String? get operatingSystemVersion;

  /// Get the local hostname for the system.
  String get localHostname;
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
