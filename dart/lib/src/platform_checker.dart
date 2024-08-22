import 'platform/platform.dart';

/// Helper to check in which enviroment the library is running.
/// The envirment checks (release/debug/profile) are mutually exclusive.
class PlatformChecker {
  static const _jsUtil = 'dart.library.js_util';

  PlatformChecker({
    this.platform = instance,
    bool? isWeb,
  }) : isWeb = isWeb ?? _isWebWithWasmSupport();

  /// Check if running in release/production environment
  bool isReleaseMode() {
    return const bool.fromEnvironment('dart.vm.product', defaultValue: false);
  }

  /// Check if running in debug environment
  bool isDebugMode() {
    return !isReleaseMode() && !isProfileMode();
  }

  /// Check if running in profile environment
  bool isProfileMode() {
    return const bool.fromEnvironment('dart.vm.profile', defaultValue: false);
  }

  final bool isWeb;

  String get compileMode {
    return isReleaseMode()
        ? 'release'
        : isDebugMode()
            ? 'debug'
            : 'profile';
  }

  /// Indicates whether a native integration is available.
  bool get hasNativeIntegration {
    if (isWeb) {
      return false;
    }
    // We need to check the platform after we checked for web, because
    // the OS checks return true when the browser runs on the checked platform.
    // Example: platform.isAndroid return true if the browser is used on an
    // Android device.
    return platform.isAndroid ||
        platform.isIOS ||
        platform.isMacOS ||
        platform.isWindows;
  }

  static bool _isWebWithWasmSupport() {
    if (const bool.hasEnvironment(_jsUtil)) {
      return const bool.fromEnvironment(_jsUtil);
    }
    return identical(0, 0.0);
  }

  final Platform platform;
}
