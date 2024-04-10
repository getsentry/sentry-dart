import 'dart:async';

import 'package:meta/meta.dart';
import 'hint.dart';

import 'hub.dart';
import 'metrics/metric.dart';
import 'metrics/metrics_aggregator.dart';
import 'metrics/metrics_api.dart';
import 'profiling.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry.dart';
import 'sentry_client.dart';
import 'sentry_user_feedback.dart';
import 'sentry_options.dart';
import 'tracing.dart';

/// Hub adapter to make Integrations testable
class HubAdapter implements Hub {
  const HubAdapter._();

  static final HubAdapter _instance = HubAdapter._();

  @override
  @internal
  SentryOptions get options => Sentry.currentHub.options;

  @override
  @internal
  MetricsApi get metricsApi => Sentry.currentHub.metricsApi;

  factory HubAdapter() {
    return _instance;
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async =>
      await Sentry.addBreadcrumb(crumb, hint: hint);

  @override
  void bindClient(SentryClient client) => Sentry.bindClient(client);

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
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
    Hint? hint,
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
    Hint? hint,
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
  FutureOr<void> configureScope(ScopeCallback callback) =>
      Sentry.configureScope(callback);

  @override
  bool get isEnabled => Sentry.isEnabled;

  @override
  SentryId get lastEventId => Sentry.lastEventId;

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    SentryTraceContextHeader? traceContext,
  }) =>
      Sentry.currentHub.captureTransaction(
        transaction,
        traceContext: traceContext,
      );

  @override
  ISentrySpan? getSpan() => Sentry.currentHub.getSpan();

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) =>
      Sentry.captureUserFeedback(userFeedback);

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
  }) =>
      Sentry.startTransactionWithContext(
        transactionContext,
        customSamplingContext: customSamplingContext,
        startTimestamp: startTimestamp,
        bindToScope: bindToScope,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd,
        onFinish: onFinish,
      );

  @override
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      Sentry.startTransaction(
        name,
        operation,
        description: description,
        startTimestamp: startTimestamp,
        bindToScope: bindToScope,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd,
        onFinish: onFinish,
        customSamplingContext: customSamplingContext,
      );

  @override
  void setSpanContext(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) =>
      Sentry.currentHub.setSpanContext(throwable, span, transaction);

  @internal
  @override
  set profilerFactory(SentryProfilerFactory? value) =>
      Sentry.currentHub.profilerFactory = value;

  @internal
  @override
  SentryProfilerFactory? get profilerFactory =>
      Sentry.currentHub.profilerFactory;

  @override
  Scope get scope => Sentry.currentHub.scope;

  @override
  Future<SentryId> captureMetrics(Map<int, Iterable<Metric>> metricsBuckets) =>
      Sentry.currentHub.captureMetrics(metricsBuckets);

  @override
  MetricsAggregator? get metricsAggregator =>
      Sentry.currentHub.metricsAggregator;
}
