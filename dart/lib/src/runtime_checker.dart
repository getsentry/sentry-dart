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

  /// Check if the Dart code is obfuscated.
  bool isAppObfuscated() {
    // In non-obfuscated builds, this will return "RuntimeChecker"
    // In obfuscated builds, this will return something like "a" or other short identifier
    // Note: Flutter Web production builds will always be minified / "obfuscated".
    final typeName = runtimeType.toString();
    return !typeName.contains('RuntimeChecker');
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
