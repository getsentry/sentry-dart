import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native_binding.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryOptions _options;

  @override
  Future<void> setContexts(String key, value) async {
    // ignore: invalid_use_of_internal_member
    if (Contexts.defaultFields.contains(key)) {
      try {
        final json = (value as dynamic).toJson();
        await _native.setContexts(key, json);
      } catch (_) {
        _options.log(
          SentryLevel.error,
          "Failed to set context '$key' with value '$value'.",
        );
      }
    } else {
      await _native.setContexts(key, value);
    }
  }

  @override
  Future<void> removeContexts(String key) async {
    await _native.removeContexts(key);
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    await _native.setUser(user);
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    await _native.addBreadcrumb(breadcrumb);
  }

  @override
  Future<void> clearBreadcrumbs() async {
    await _native.clearBreadcrumbs();
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
