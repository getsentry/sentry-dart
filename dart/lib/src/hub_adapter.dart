import 'dart:async';

import 'hub.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_client.dart';
import 'sentry_user_feedback.dart';
import 'tracing.dart';

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
        withScope: withScope,
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
  Future<SentryId> captureTransaction(SentryTransaction transaction) =>
      Sentry.currentHub.captureTransaction(transaction);

  @override
  ISentrySpan? getSpan() => Sentry.currentHub.getSpan();

  @override
  Future captureUserFeedback(SentryUserFeedback userFeedback) =>
      Sentry.captureUserFeedback(userFeedback);

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    bool? bindToScope,
  }) =>
      Sentry.startTransactionWithContext(
        transactionContext,
        customSamplingContext: customSamplingContext,
        bindToScope: bindToScope,
      );

  @override
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    bool? bindToScope,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      Sentry.startTransaction(
        name,
        operation,
        description: description,
        bindToScope: bindToScope,
        customSamplingContext: customSamplingContext,
      );

  @override
  void setSpanContext(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) =>
      Sentry.currentHub.setSpanContext(throwable, span, transaction);
}
