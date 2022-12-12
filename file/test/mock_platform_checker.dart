import 'no_such_method_provider.dart';
import 'package:sentry/src/platform_checker.dart';

class MockPlatformChecker extends PlatformChecker with NoSuchMethodProvider {
  MockPlatformChecker(this._isWeb);

  final bool _isWeb;

  @override
  bool get isWeb => _isWeb;
}
