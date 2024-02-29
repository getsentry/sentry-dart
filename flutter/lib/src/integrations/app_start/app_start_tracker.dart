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
  factory AppStartTracker() => _instance;
  AppStartTracker._internal();

  Completer<AppStartInfo?> _appStartCompleter = Completer<AppStartInfo?>();
  AppStartInfo? _appStartInfo;

  void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    if (!_appStartCompleter.isCompleted) {
      _appStartCompleter.complete(appStartInfo);
    } else {
      _appStartCompleter = Completer<AppStartInfo?>();
      _appStartCompleter.complete(appStartInfo);
    }
  }

  Future<AppStartInfo?> getAppStartInfo() {
    if (_appStartInfo != null) {
      return Future.value(_appStartInfo);
    }
    return _appStartCompleter.future;
  }
}
