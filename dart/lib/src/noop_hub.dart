import 'dart:async';
import 'hub.dart';
import 'protocol.dart';
import 'sentry_client.dart';
import 'user_feedback.dart';

class NoOpHub implements Hub {
  NoOpHub._();

  static final NoOpHub _instance = NoOpHub._();

  factory NoOpHub() {
    return _instance;
  }

  @override
  void bindClient(SentryClient client) {}

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Future.value(SentryId.empty());

  @override
  Hub clone() => this;

  @override
  Future<void> close() async {}

  @override
  void configureScope(callback) {}

  @override
  bool get isEnabled => false;

  @override
  SentryId get lastEventId => SentryId.empty();

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {}

  @override
  Future<void> captureUserFeedback(UserFeedback userFeedback) async {}
}
