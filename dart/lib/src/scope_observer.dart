import '../sentry.dart';

abstract class ScopeObserver {
  void setUser(SentryUser? user);
  void addBreadcrumb(Breadcrumb breadcrumb);
}
