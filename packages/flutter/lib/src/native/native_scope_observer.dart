import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native_binding.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryOptions _options;

  @override
  FutureOr<void> setContexts(String key, value) {
    // ignore: invalid_use_of_internal_member
    if (Contexts.defaultFields.contains(key)) {
      try {
        final json = (value as dynamic).toJson();
        return _native.setContexts(key, json);
      } catch (_) {
        _options.log(
          SentryLevel.error,
          "Failed to set context '$key' with value '$value'.",
        );
      }
    } else {
      return _native.setContexts(key, value);
    }
  }

  @override
  FutureOr<void> removeContexts(String key) {
    return _native.removeContexts(key);
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    return _native.setUser(user);
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    return _native.addBreadcrumb(breadcrumb);
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    return _native.clearBreadcrumbs();
  }

  @override
  Future<void> setExtra(String key, dynamic value) async {
    await _native.setExtra(key, value);
  }

  @override
  Future<void> removeExtra(String key) async {
    await _native.removeExtra(key);
  }

  @override
  Future<void> setTag(String key, String value) async {
    await _native.setTag(key, value);
  }

  @override
  Future<void> removeTag(String key) async {
    await _native.removeTag(key);
  }
}
