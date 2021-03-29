import 'package:sentry/src/platform_checker.dart';

/// Fake class to be used in unit tests for mocking different environments
class FakePlatformChecker extends PlatformChecker {
  FakePlatformChecker.releaseMode() {
    _releaseMode = true;
    _debugMode = false;
    _profileMode = false;
  }

  FakePlatformChecker.debugMode() {
    _releaseMode = false;
    _debugMode = true;
    _profileMode = false;
  }

  FakePlatformChecker.profileMode() {
    _releaseMode = false;
    _debugMode = false;
    _profileMode = true;
  }

  late bool _releaseMode;
  late bool _debugMode;
  late bool _profileMode;

  @override
  bool isReleaseMode() {
    return _releaseMode;
  }

  @override
  bool isDebugMode() {
    return _debugMode;
  }

  @override
  bool isProfileMode() {
    return _profileMode;
  }
}
