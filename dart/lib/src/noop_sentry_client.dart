import 'dart:async';

import 'package:meta/meta.dart';

import 'hint.dart';
import 'metrics/metric.dart';
import 'metrics/metrics_aggregator.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_client.dart';
import 'sentry_envelope.dart';
import 'sentry_trace_context_header.dart';
import 'sentry_user_feedback.dart';

class NoOpSentryClient implements SentryClient {
  NoOpSentryClient._();

  static final NoOpSentryClient _instance = NoOpSentryClient._();

  factory NoOpSentryClient() {
    return _instance;
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Scope? scope,
    Hint? hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Scope? scope,
    Hint? hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    Scope? scope,
    Hint? hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureEnvelope(SentryEnvelope envelope) async =>
      SentryId.empty();

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {}

  @override
  Future<void> close() async {}

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
  }) async =>
      SentryId.empty();

  @override
  @internal
  Future<SentryId> captureMetrics(
          Map<int, Iterable<Metric>> metricsBuckets) async =>
      SentryId.empty();

  @override
  @internal
  MetricsAggregator? get metricsAggregator => null;
}
