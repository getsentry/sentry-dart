import 'package:sentry/src/platform_checker.dart';

import 'no_such_method_provider.dart';

class MockPlatformChecker extends PlatformChecker with NoSuchMethodProvider {
  MockPlatformChecker({
    this.isDebug = false,
    this.isProfile = false,
    this.isRelease = false,
  });

  final bool isDebug;
  final bool isProfile;
  final bool isRelease;

  @override
  bool isDebugMode() => isDebug;

  @override
  bool isProfileMode() => isProfile;

  @override
  bool isReleaseMode() => isRelease;
}
