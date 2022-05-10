import 'dart:async';

import '../sentry.dart';

abstract class ScopeObserver {
  FutureOr<void> setUser(SentryUser? user);
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb);
  FutureOr<void> clearBreadcrumbs();
  FutureOr<void> setExtra(String key, dynamic value);
}
