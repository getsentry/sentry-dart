import 'dart:async';
import 'platform/platform.dart';

/// Helper to check in which environment the library is running.
/// The environment checks (release/debug/profile) are mutually exclusive.
// TODO rename this to `RuntimeChecker` or something similar to better represent what it does.
// TODO move `platform` directly to options - that is what we actually access 99 % of the times in tests and lib.
class PlatformChecker {
  PlatformChecker({
    this.platform = currentPlatform,
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

  // TODO remove this check - it should be handled by the native integration... also, it's actually always true...
  /// Indicates whether a native integration is available.
  bool get hasNativeIntegration =>
      platform.isWeb ||
      platform.isAndroid ||
      platform.isIOS ||
      platform.isMacOS ||
      platform.isWindows ||
      platform.isLinux;

  final Platform platform;
}
