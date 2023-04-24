import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._sentryNative);

  final SentryNative _sentryNative;

  @override
  Future<void> setContexts(String key, value) async {
    await _sentryNative.setContexts(key, value);
  }

  @override
  Future<void> removeContexts(String key) async {
    await _sentryNative.removeContexts(key);
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    await _sentryNative.setUser(user);
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    await _sentryNative.addBreadcrumb(breadcrumb);
  }

  @override
  Future<void> clearBreadcrumbs() async {
    await _sentryNative.clearBreadcrumbs();
  }

  @override
  Future<void> setExtra(String key, dynamic value) async {
    await _sentryNative.setExtra(key, value);
  }

  @override
  Future<void> removeExtra(String key) async {
    await _sentryNative.removeExtra(key);
  }

  @override
  Future<void> setTag(String key, String value) async {
    await _sentryNative.setTag(key, value);
  }

  @override
  Future<void> removeTag(String key) async {
    await _sentryNative.removeTag(key);
  }
}
