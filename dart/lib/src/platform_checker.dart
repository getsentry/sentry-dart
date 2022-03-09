import 'platform/platform.dart';

/// Helper to check in which enviroment the library is running.
/// The envirment checks (release/debug/profile) are mutually exclusive.
class PlatformChecker {
  const PlatformChecker({
    this.platform = instance,
    this.isWeb = identical(0, 0.0),
  });

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

  /// Indicates wether a native integration is available.
  bool get hasNativeIntegration {
    if (isWeb) {
      return false;
    }
    // We need to check the platform after we checked for web, because
    // the OS checks return true when the browser runs on the checked platform.
    // Example: platform.isAndroid return true if the browser is used on an
    // Android device.
    if (platform.isAndroid || platform.isIOS || platform.isMacOS) {
      return true;
    }
    return false;
  }

  final Platform platform;
}
