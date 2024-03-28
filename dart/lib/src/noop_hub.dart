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
import 'sentry_client.dart';
import 'sentry_options.dart';
import 'sentry_user_feedback.dart';
import 'tracing.dart';

class NoOpHub implements Hub {
  NoOpHub._() {
    _metricsApi = MetricsApi(hub: this);
  }

  static final NoOpHub _instance = NoOpHub._();

  final _options = SentryOptions.empty();

  late final MetricsApi _metricsApi;

  @override
  @internal
  SentryOptions get options => _options;

  @override
  @internal
  MetricsApi get metricsApi => _metricsApi;

  factory NoOpHub() {
    return _instance;
  }

  @override
  void bindClient(SentryClient client) {}

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List? params,
    Hint? hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

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
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {}

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    SentryTraceContextHeader? traceContext,
  }) async =>
      SentryId.empty();

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {}

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
      NoOpSentrySpan();

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
      NoOpSentrySpan();

  @override
  ISentrySpan? getSpan() => null;

  @override
  void setSpanContext(throwable, ISentrySpan span, String transaction) {}

  @internal
  @override
  set profilerFactory(SentryProfilerFactory? value) {}

  @internal
  @override
  SentryProfilerFactory? get profilerFactory => null;

  @override
  Scope get scope => Scope(_options);

  @override
  @internal
  Future<SentryId> captureMetrics(
          Map<int, Iterable<Metric>> metricsBuckets) async =>
      SentryId.empty();

  @override
  @internal
  MetricsAggregator? get metricsAggregator => null;
}
