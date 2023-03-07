import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'sentry_native_channel.dart';

/// [SentryNative] holds state that it fetches from to the native SDKs. Always
/// use the shared instance with [SentryNative()].
@internal
class SentryNative {
  SentryNative._();

  static final SentryNative _instance = SentryNative._();

  SentryNativeChannel? _nativeChannel;

  factory SentryNative() {
    return _instance;
  }

  SentryNativeChannel? get nativeChannel => _instance._nativeChannel;

  /// Provide [nativeChannel] for native communication.
  set nativeChannel(SentryNativeChannel? nativeChannel) {
    _instance._nativeChannel = nativeChannel;
  }

  // AppStart

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;

  bool _didFetchAppStart = false;

  /// Flag indicating if app start was already fetched.
  bool get didFetchAppStart => _didFetchAppStart;

  /// Fetch [NativeAppStart] from native channels. Can only be called once.
  Future<NativeAppStart?> fetchNativeAppStart() async {
    _didFetchAppStart = true;
    return await _nativeChannel?.fetchNativeAppStart();
  }

  // Scope

  Future<void> setContexts(String key, dynamic value) async {
    return await _nativeChannel?.setContexts(key, value);
  }

  Future<void> removeContexts(String key) async {
    return await _nativeChannel?.removeContexts(key);
  }

  Future<void> setUser(SentryUser? sentryUser) async {
    return await _nativeChannel?.setUser(sentryUser);
  }

  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    return await _nativeChannel?.addBreadcrumb(breadcrumb);
  }

  Future<void> clearBreadcrumbs() async {
    return await _nativeChannel?.clearBreadcrumbs();
  }

  Future<void> setExtra(String key, dynamic value) async {
    return await _nativeChannel?.setExtra(key, value);
  }

  Future<void> removeExtra(String key) async {
    return await _nativeChannel?.removeExtra(key);
  }

  Future<void> setTag(String key, String value) async {
    return await _nativeChannel?.setTag(key, value);
  }

  Future<void> removeTag(String key) async {
    return await _nativeChannel?.removeTag(key);
  }

  /// Reset state
  void reset() {
    appStartEnd = null;
    _didFetchAppStart = false;
  }
}
