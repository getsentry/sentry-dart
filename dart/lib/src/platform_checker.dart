class PlatformChecker {
  const PlatformChecker();

  bool isReleaseMode() {
    return bool.fromEnvironment('dart.vm.product', defaultValue: false);
  }

  bool isDebugMode() {
    return !isReleaseMode() && !isProfileMode();
  }

  bool isProfileMode() {
    return bool.fromEnvironment('dart.vm.profile', defaultValue: false);
  }
}
