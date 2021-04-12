import 'platform/platform.dart';

/// Helper to check in which enviroment the library is running.
/// The envirment checks (release/debug/profile) are mutually exclusive.
class PlatformChecker {
  PlatformChecker({
    this.platform = instance,
    this.isWeb = runsOnWeb,
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

  /// Indicates wether a native integration is available.
  bool get hasNativeIntegration {
    if (isWeb) {
      // On web platform OS checks return the OS the browser is running on
      return false;
    }
    if (platform.isAndroid || platform.isIOS || platform.isMacOS) {
      return true;
    }
    return false;
  }

  final Platform platform;
}

/// helper to detect a browser context
const runsOnWeb = identical(0, 0.0);
