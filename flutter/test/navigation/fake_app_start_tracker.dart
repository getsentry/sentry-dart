import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';

class FakeAppStartTracker extends IAppStartTracker {
  static final FakeAppStartTracker _instance = FakeAppStartTracker._internal();

  factory FakeAppStartTracker() => _instance;

  AppStartInfo? _appStartInfo;

  FakeAppStartTracker._internal();

  @override
  AppStartInfo? get appStartInfo => _appStartInfo;

  @override
  void onAppStartComplete(void Function(AppStartInfo?) callback) {
    callback(_appStartInfo);
  }

  @override
  void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
  }
}
