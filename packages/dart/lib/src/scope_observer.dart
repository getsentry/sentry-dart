import 'dart:async';

import 'hint.dart';
import 'protocol/breadcrumb.dart';
import 'protocol/sentry_user.dart';

abstract class ScopeObserver {
  FutureOr<void> setContexts(String key, dynamic value);
  FutureOr<void> removeContexts(String key);
  FutureOr<void> setUser(SentryUser? user);
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb, Hint hint);
  FutureOr<void> clearBreadcrumbs();
  Future<void> setExtra(String key, dynamic value);
  Future<void> removeExtra(String key);
  Future<void> setTag(String key, String value);
  Future<void> removeTag(String key);
}
