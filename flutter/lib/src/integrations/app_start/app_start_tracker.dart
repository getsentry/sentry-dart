import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';

@internal
class AppStartInfo {
  final DateTime start;
  final DateTime end;
  final SentryMeasurement measurement;

  AppStartInfo(this.start, this.end, this.measurement);
}

@internal
class AppStartTracker {
  static final AppStartTracker _instance = AppStartTracker._internal();
  Completer<AppStartInfo?> _appStartCompleter = Completer<AppStartInfo?>();

  factory AppStartTracker() => _instance;

  AppStartInfo? _appStartInfo;

  AppStartTracker._internal();

  void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    if (!_appStartCompleter.isCompleted) {
      // Complete the completer with the app start info when it becomes available
      _appStartCompleter.complete(appStartInfo);
    } else {
      // If setAppStartInfo is called again, reset the completer with new app start info
      _appStartCompleter = Completer<AppStartInfo?>();
      _appStartCompleter.complete(appStartInfo);
    }
  }

  Future<AppStartInfo?> getAppStartInfo() {
    // If the app start info is already set, return it immediately
    if (_appStartInfo != null) {
      return Future.value(_appStartInfo);
    }
    // Otherwise, return the future that will complete when the app start info is set
    return _appStartCompleter.future;
  }
}
