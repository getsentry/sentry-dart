import 'package:sentry/sentry.dart';

class MockScopeObserver extends ScopeObserver {
  bool calledAddBreadcrumb = false;
  bool calledClearBreadcrumbs = false;
  bool calledRemoveContexts = false;
  bool calledRemoveExtra = false;
  bool calledRemoveTag = false;
  bool calledSetContexts = false;
  bool calledSetExtra = false;
  bool calledSetTag = false;
  bool calledSetUser = false;

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    calledAddBreadcrumb = true;
  }

  @override
  Future<void> clearBreadcrumbs() async {
    calledClearBreadcrumbs = true;
  }

  @override
  Future<void> removeContexts(String key) async {
    calledRemoveContexts = true;
  }

  @override
  Future<void> removeExtra(String key) async {
    calledRemoveExtra = true;
  }

  @override
  Future<void> removeTag(String key) async {
    calledRemoveTag = true;
  }

  @override
  Future<void> setContexts(String key, value) async {
    calledSetContexts = true;
  }

  @override
  Future<void> setExtra(String key, value) async {
    calledSetExtra = true;
  }

  @override
  Future<void> setTag(String key, String value) async {
    calledSetTag = true;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    calledSetUser = true;
  }
}
