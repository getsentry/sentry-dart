import 'dart:async';

import 'utils/stacktrace_utils.dart';

/// Helper to check in which environment the library is running.
/// The environment checks (release/debug/profile) are mutually exclusive.
class RuntimeChecker {
  RuntimeChecker({
    bool? isRootZone,
  }) : isRootZone = isRootZone ?? Zone.current == Zone.root;

  /// Whether running in release/production environment as a compile-time constant for guaranteed tree-shaking.
  ///
  /// If the code needs to be testable, use [isReleaseMode] instead.
  static const bool kReleaseMode =
      bool.fromEnvironment('dart.vm.product', defaultValue: false);

  /// Whether running in profile environment as a compile-time constant for guaranteed tree-shaking.
  ///
  /// If the code needs to be testable, use [isProfileMode] instead.
  static const bool kProfileMode =
      bool.fromEnvironment('dart.vm.profile', defaultValue: false);

  /// Whether running in debug environment as a compile-time constant for guaranteed tree-shaking.
  ///
  /// If the code needs to be testable, use [isDebugMode] instead.
  static const bool kDebugMode = !kReleaseMode && !kProfileMode;

  /// Whether running in release/production environment.
  ///
  /// Code paths using this method are not guaranteed to be tree-shaken in release builds.
  /// If tree-shaking needs to be guaranteed, use [RuntimeChecker.kReleaseMode] instead.
  bool isReleaseMode() => kReleaseMode;

  /// Whether running in debug environment.
  ///
  /// Code paths using this method are not guaranteed to be tree-shaken in non-debug builds.
  /// If tree-shaking needs to be guaranteed, use [RuntimeChecker.kDebugMode] instead.
  bool isDebugMode() => kDebugMode;

  /// Whether running in profile environment.
  ///
  /// Code paths using this method are not guaranteed to be tree-shaken in profile builds.
  /// If tree-shaking needs to be guaranteed, use [RuntimeChecker.kProfileMode] instead.
  bool isProfileMode() => kProfileMode;

  /// Check if the Dart code is obfuscated.
  bool isAppObfuscated() {
    // In non-obfuscated builds, this will return "RuntimeChecker"
    // In obfuscated builds, this will return something like "a" or other short identifier
    // Note: Flutter Web production builds will always be minified / "obfuscated".
    final typeName = runtimeType.toString();
    return !typeName.contains('RuntimeChecker');
  }

  /// Check if the current build has been built with --split-debug-info
  bool isSplitDebugInfoBuild() {
    final str = StackTrace.current.toString();
    return buildIdRegex.hasMatch(str) || absRegex.hasMatch(str);
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
