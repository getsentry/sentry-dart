import 'package:sentry/src/runtime_checker.dart';

import 'no_such_method_provider.dart';

class MockRuntimeChecker extends RuntimeChecker with NoSuchMethodProvider {
  MockRuntimeChecker({
    this.isDebug = false,
    this.isProfile = false,
    this.isRelease = false,
    bool isRootZone = true,
  }) : super(isRootZone: isRootZone);

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
