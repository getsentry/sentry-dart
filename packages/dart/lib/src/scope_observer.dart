import 'dart:async';

import 'hint.dart';
import 'protocol/breadcrumb.dart';
import 'protocol/sentry_user.dart';

abstract class ScopeObserver {
  FutureOr<void> setContexts(String key, dynamic value);
  FutureOr<void> removeContexts(String key);
  FutureOr<void> setUser(SentryUser? user);
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb);
  FutureOr<void> clearBreadcrumbs();
  Future<void> setExtra(String key, dynamic value);
  Future<void> removeExtra(String key);
  Future<void> setTag(String key, String value);
  Future<void> removeTag(String key);
}

/// Additive opt-in for [ScopeObserver] implementations that need the
/// [Hint] associated with a breadcrumb (e.g. to correlate out-of-band data
/// such as Session Replay network detail).
///
/// When a [ScopeObserver] also implements this interface, [Scope] calls
/// [addBreadcrumbWithHint] instead of [ScopeObserver.addBreadcrumb]. This
/// keeps [ScopeObserver.addBreadcrumb]'s signature stable for existing
/// implementors.
abstract class HintAwareScopeObserver {
  FutureOr<void> addBreadcrumbWithHint(Breadcrumb breadcrumb, Hint hint);
}
