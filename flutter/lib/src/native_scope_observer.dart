import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._sentryNative);

  final SentryNative _sentryNative;

  @override
  FutureOr<void> setUser(SentryUser? user) async {
    await _sentryNative.setUser(user);
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    await _sentryNative.addBreadcrumb(breadcrumb);
  }

  @override
  FutureOr<void> clearBreadcrumbs() async {
    await _sentryNative.clearBreadcrumbs();
  }

  @override
  FutureOr<void> setExtra(String key, dynamic value) async {
    await _sentryNative.setExtra(key, value);
  }

  @override
  FutureOr<void> setTag(String key, String value) async {
    await _sentryNative.setExtra(key, value);
  }
}
