import '../sentry.dart';

abstract class ScopeObserver {
  void setUser(SentryUser? user);
}
