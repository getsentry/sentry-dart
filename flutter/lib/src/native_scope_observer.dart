import 'package:sentry/sentry.dart';

import 'sentry_native.dart';

class NativeScopeObserver implements ScopeObserver {
  NativeScopeObserver(this._sentryNative);

  final SentryNative _sentryNative;

  @override
  void setUser(SentryUser? user) {
    _sentryNative.setUser(user);
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    _sentryNative.addBreadcrumb(breadcrumb);
  }
}
