import '_io_platform.dart'
    if (dart.library.html) '_html_platform.dart'
    if (dart.library.js_interop) '_web_platform.dart' as platform;

const Platform instance = platform.instance;

abstract class Platform {
  const Platform();

  /// A string (`linux`, `macos`, `windows`, `android`, `ios`, or `fuchsia`)
  /// representing the operating system.
  String get operatingSystem;

  /// A string representing the version of the operating system or platform.
  String get operatingSystemVersion;

  /// Get the local hostname for the system.
  String get localHostname;

  /// True if the operating system is Linux.
  bool get isLinux => (operatingSystem == 'linux');

  /// True if the operating system is OS X.
  bool get isMacOS => (operatingSystem == 'macos');

  /// True if the operating system is Windows.
  bool get isWindows => (operatingSystem == 'windows');

  /// True if the operating system is Android.
  bool get isAndroid => (operatingSystem == 'android');

  /// True if the operating system is iOS.
  bool get isIOS => (operatingSystem == 'ios');

  /// True if the operating system is Fuchsia
  bool get isFuchsia => (operatingSystem == 'fuchsia');
}
