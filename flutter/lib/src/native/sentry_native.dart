import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native_binding.dart';

/// [SentryNative] holds state that it fetches from to the native SDKs.
/// It forwards to platform-specific implementations of [SentryNativeBinding].
/// Any errors are logged and ignored.
@internal
class SentryNative {
  final SentryOptions _options;
  final SentryNativeBinding _binding;

  SentryNative(this._options, this._binding);

  // AppStart

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;

  bool _didFetchAppStart = false;

  /// Flag indicating if app start was already fetched.
  bool get didFetchAppStart => _didFetchAppStart;

  /// Flag indicating if app start measurement was added to the first transaction.
  bool didAddAppStartMeasurement = false;

  Future<void> init(SentryFlutterOptions options) async =>
      _invoke("init", () => _binding.init(options));

  Future<void> close() async => _invoke("close", _binding.close);

  /// Fetch [NativeAppStart] from native channels. Can only be called once.
  Future<NativeAppStart?> fetchNativeAppStart() async {
    _didFetchAppStart = true;
    return _invoke("fetchNativeAppStart", _binding.fetchNativeAppStart);
  }

  // NativeFrames

  Future<void> beginNativeFramesCollection() =>
      _invoke("beginNativeFrames", _binding.beginNativeFrames);

  Future<NativeFrames?> endNativeFramesCollection(SentryId traceId) =>
      _invoke("endNativeFrames", () => _binding.endNativeFrames(traceId));

  // Scope

  Future<void> setContexts(String key, dynamic value) =>
      _invoke("setContexts", () => _binding.setContexts(key, value));

  Future<void> removeContexts(String key) =>
      _invoke("removeContexts", () => _binding.removeContexts(key));

  Future<void> setUser(SentryUser? sentryUser) =>
      _invoke("setUser", () => _binding.setUser(sentryUser));

  Future<void> addBreadcrumb(Breadcrumb breadcrumb) =>
      _invoke("addBreadcrumb", () => _binding.addBreadcrumb(breadcrumb));

  Future<void> clearBreadcrumbs() =>
      _invoke("clearBreadcrumbs", _binding.clearBreadcrumbs);

  Future<void> setExtra(String key, dynamic value) =>
      _invoke("setExtra", () => _binding.setExtra(key, value));

  Future<void> removeExtra(String key) =>
      _invoke("removeExtra", () => _binding.removeExtra(key));

  Future<void> setTag(String key, String value) =>
      _invoke("setTag", () => _binding.setTag(key, value));

  Future<void> removeTag(String key) =>
      _invoke("removeTag", () => _binding.removeTag(key));

  int? startProfiler(SentryId traceId) =>
      _invokeSync("startProfiler", () => _binding.startProfiler(traceId));

  Future<void> discardProfiler(SentryId traceId) =>
      _invoke("discardProfiler", () => _binding.discardProfiler(traceId));

  Future<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      _invoke("collectProfile",
          () => _binding.collectProfile(traceId, startTimeNs, endTimeNs));

  /// Reset state
  void reset() {
    appStartEnd = null;
    _didFetchAppStart = false;
  }

  // Helpers
  Future<T?> _invoke<T>(
      String nativeMethodName, Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (error, stackTrace) {
      _logError(nativeMethodName, error, stackTrace);
      // ignore: invalid_use_of_internal_member
      if (_options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  T? _invokeSync<T>(String nativeMethodName, T? Function() fn) {
    try {
      return fn();
    } catch (error, stackTrace) {
      _logError(nativeMethodName, error, stackTrace);
      // ignore: invalid_use_of_internal_member
      if (_options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  void _logError(String nativeMethodName, Object error, StackTrace stackTrace) {
    _options.logger(
      SentryLevel.error,
      'Native call `$nativeMethodName` failed',
      exception: error,
      stackTrace: stackTrace,
    );
  }
}

class NativeAppStart {
  NativeAppStart(
      {required this.appStartTime,
      required this.pluginRegistrationTime,
      required this.isColdStart,
      required this.nativeSpanTimes});

  double appStartTime;
  int pluginRegistrationTime;
  bool isColdStart;
  Map<dynamic, dynamic> nativeSpanTimes;

  factory NativeAppStart.fromJson(Map<String, dynamic> json) {
    return NativeAppStart(
      appStartTime: json['appStartTime'] as double,
      pluginRegistrationTime: json['pluginRegistrationTime'] as int,
      isColdStart: json['isColdStart'] as bool,
      nativeSpanTimes: json['nativeSpanTimes'] as Map<dynamic, dynamic>,
    );
  }
}

class NativeFrames {
  NativeFrames(this.totalFrames, this.slowFrames, this.frozenFrames);

  int totalFrames;
  int slowFrames;
  int frozenFrames;

  factory NativeFrames.fromJson(Map<String, dynamic> json) {
    return NativeFrames(
      json['totalFrames'] as int,
      json['slowFrames'] as int,
      json['frozenFrames'] as int,
    );
  }
}
