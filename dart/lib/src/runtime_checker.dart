import 'dart:async';

/// Helper to check in which environment the library is running.
/// The environment checks (release/debug/profile) are mutually exclusive.
class RuntimeChecker {
  RuntimeChecker({
    bool? isRootZone,
  }) : isRootZone = isRootZone ?? Zone.current == Zone.root;

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

  final bool isRootZone;

  String get compileMode {
    return isReleaseMode()
        ? 'release'
        : isDebugMode()
            ? 'debug'
            : 'profile';
  }
}
