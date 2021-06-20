import 'dart:async';
import 'hub.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_client.dart';
import 'user_feedback.dart';

/// Hub adapter to make Integrations testable
class HubAdapter implements Hub {
  const HubAdapter._();

  static final HubAdapter _instance = HubAdapter._();

  factory HubAdapter() {
    return _instance;
  }

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) =>
      Sentry.addBreadcrumb(crumb, hint: hint);

  @override
  void bindClient(SentryClient client) => Sentry.bindClient(client);

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Sentry.captureEvent(
        event,
        stackTrace: stackTrace,
        hint: hint,
        withScope: withScope,
      );

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        hint: hint,
        withScope: withScope,
      );

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) =>
      Sentry.captureMessage(
        message,
        level: level,
        template: template,
        params: params,
        hint: hint,
      );

  @override
  Hub clone() => Sentry.clone();

  @override
  Future<void> close() => Sentry.close();

  @override
  void configureScope(ScopeCallback callback) =>
      Sentry.configureScope(callback);

  @override
  bool get isEnabled => Sentry.isEnabled;

  @override
  SentryId get lastEventId => Sentry.lastEventId;

  @override
  Future<void> captureUserFeedback(UserFeedback userFeedback) =>
      Sentry.captureUserFeedback(userFeedback);
}
