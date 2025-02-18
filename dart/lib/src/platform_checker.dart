import 'dart:async';
import 'package:platform/platform.dart';
import 'platform/platform.dart' as pf;

/// Helper to check in which environment the library is running.
/// The environment checks (release/debug/profile) are mutually exclusive.
class PlatformChecker {
  static const _jsUtil = 'dart.library.js_util';

  PlatformChecker({
    this.platform = pf.instance,
    bool? isWeb,
    bool? isRootZone,
  })  : isWeb = isWeb ?? _isWebWithWasmSupport(),
        isRootZone = isRootZone ?? Zone.current == Zone.root;

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
  final bool isRootZone;

  String get compileMode {
    return isReleaseMode()
        ? 'release'
        : isDebugMode()
            ? 'debug'
            : 'profile';
  }

  /// Indicates whether a native integration is available.
  bool get hasNativeIntegration =>
      isWeb ||
      platform.isAndroid ||
      platform.isIOS ||
      platform.isMacOS ||
      platform.isWindows ||
      platform.isLinux;

  static bool _isWebWithWasmSupport() {
    if (const bool.hasEnvironment(_jsUtil)) {
      return const bool.fromEnvironment(_jsUtil);
    }
    return identical(0, 0.0);
  }

  final Platform platform;
}
