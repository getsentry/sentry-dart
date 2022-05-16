import 'dart:async';

import '../sentry.dart';

abstract class ScopeObserver {
  FutureOr<void> setContexts(String key, dynamic value);
  FutureOr<void> removeContexts(String key);
  FutureOr<void> setUser(SentryUser? user);
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb);
  FutureOr<void> clearBreadcrumbs();
  FutureOr<void> setExtra(String key, dynamic value);
  FutureOr<void> removeExtra(String key);
  FutureOr<void> setTag(String key, String value);
  FutureOr<void> removeTag(String key);
}
