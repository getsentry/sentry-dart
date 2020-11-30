/// Helper to check in which enviroment the library is running.
/// The envirment checks (release/debug/profile) are mutually exclusive.
class PlatformChecker {
  const PlatformChecker();

  /// Check if running in release/production environment
  bool isReleaseMode() {
    return bool.fromEnvironment('dart.vm.product', defaultValue: false);
  }

  /// Check if running in debug environment
  bool isDebugMode() {
    return !isReleaseMode() && !isProfileMode();
  }

  /// Check if running in profile environment
  bool isProfileMode() {
    return bool.fromEnvironment('dart.vm.profile', defaultValue: false);
  }
}
