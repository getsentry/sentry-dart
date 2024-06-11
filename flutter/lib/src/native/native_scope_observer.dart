import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native_binding.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._native);

  final SentryNativeBinding _native;

  @override
  Future<void> setContexts(String key, value) async {
    await _native.setContexts(key, value);
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
