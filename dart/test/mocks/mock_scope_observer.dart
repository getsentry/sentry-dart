import 'package:sentry/sentry.dart';

class MockScopeObserver extends ScopeObserver {
  List<Breadcrumb> addedBreadcrumbs = [];
  bool calledAddBreadcrumb = false;
  bool calledClearBreadcrumbs = false;
  bool calledRemoveContexts = false;
  bool calledRemoveExtra = false;
  bool calledRemoveTag = false;
  bool calledSetContexts = false;
  bool calledSetExtra = false;
  bool calledSetTag = false;
  bool calledSetUser = false;

  int numberOfAddBreadcrumbCalls = 0;
  int numberOfClearBreadcrumbsCalls = 0;
  int numberOfRemoveContextsCalls = 0;
  int numberOfRemoveExtraCalls = 0;
  int numberOfRemoveTagCalls = 0;
  int numberOfSetContextsCalls = 0;
  int numberOfSetExtraCalls = 0;
  int numberOfSetTagCalls = 0;
  int numberOfSetUserCalls = 0;

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    calledAddBreadcrumb = true;
    numberOfAddBreadcrumbCalls += 1;
    addedBreadcrumbs.add(breadcrumb);
  }

  @override
  Future<void> clearBreadcrumbs() async {
    calledClearBreadcrumbs = true;
    numberOfClearBreadcrumbsCalls += 1;
  }

  @override
  Future<void> removeContexts(String key) async {
    calledRemoveContexts = true;
    numberOfRemoveContextsCalls += 1;
  }

  @override
  Future<void> removeExtra(String key) async {
    calledRemoveExtra = true;
    numberOfRemoveExtraCalls += 1;
  }

  @override
  Future<void> removeTag(String key) async {
    calledRemoveTag = true;
    numberOfRemoveTagCalls += 1;
  }

  @override
  Future<void> setContexts(String key, value) async {
    calledSetContexts = true;
    numberOfSetContextsCalls += 1;
  }

  @override
  Future<void> setExtra(String key, value) async {
    calledSetExtra = true;
    numberOfSetExtraCalls += 1;
  }

  @override
  Future<void> setTag(String key, String value) async {
    calledSetTag = true;
    numberOfSetTagCalls += 1;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    calledSetUser = true;
    numberOfSetUserCalls += 1;
  }
}
