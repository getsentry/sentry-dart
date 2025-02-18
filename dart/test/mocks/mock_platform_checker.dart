import 'package:sentry/src/platform/platform.dart';
import 'package:sentry/src/platform_checker.dart';

import 'no_such_method_provider.dart';

class MockPlatformChecker extends PlatformChecker with NoSuchMethodProvider {
  MockPlatformChecker({
    this.isDebug = false,
    this.isProfile = false,
    this.isRelease = false,
    this.hasNativeIntegration = false,
    Platform? platform,
  }) : _platform = platform;

  final Platform? _platform;

  final bool isDebug;
  final bool isProfile;
  final bool isRelease;

  @override
  bool hasNativeIntegration = false;

  @override
  bool isDebugMode() => isDebug;

  @override
  bool isProfileMode() => isProfile;

  @override
  bool isReleaseMode() => isRelease;

  @override
  Platform get platform => _platform ?? super.platform;
}
