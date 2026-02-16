import 'dart:async';

import 'package:meta/meta.dart';

import 'hint.dart';
import 'hub.dart';
import 'profiling.dart';
import 'protocol.dart';
import 'protocol/sentry_feedback.dart';
import 'scope.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';
import 'telemetry/metric/metric.dart';
import 'telemetry/span/idle_span_controller.dart';
import 'telemetry/span/sentry_span_status_v2.dart';
import 'telemetry/span/sentry_span_v2.dart';
import 'tracing.dart';

class NoOpHub implements Hub {
  NoOpHub._();

  static final NoOpHub _instance = NoOpHub._();

  final _options = SentryOptions.empty();

  @override
  @internal
  SentryOptions get options => _options;

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
    SentryMessage? message,
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
    Hint? hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureFeedback(
    SentryFeedback feedback, {
    Hint? hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

  @override
  FutureOr<void> captureLog(SentryLog log) async {}

  @override
  Future<void> captureMetric(SentryMetric metric) async {}

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
  void generateNewTrace() {}

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
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  void removeAttribute(String key) {}

  @override
  SentrySpanV2 startInactiveSpan(
    String name, {
    SentrySpanV2? parentSpan = const UnsetSentrySpanV2(),
    Map<String, SentryAttribute>? attributes,
  }) =>
      NoOpSentrySpanV2.instance;

  @override
  Future<void> captureSpan(SentrySpanV2 span) async {}

  @override
  RecordingSentrySpanV2? getActiveSpan() {
    return null;
  }

  @override
  IdleSpanController? get idleSpanController => null;

  @override
  FutureOr<T> startSpan<T>(
      String name, FutureOr<T> Function(SentrySpanV2 span) callback,
      {Map<String, SentryAttribute>? attributes,
      SentrySpanV2? parentSpan = const UnsetSentrySpanV2()}) {
    return callback(NoOpSentrySpanV2.instance);
  }

  @override
  void endIdleSpan({SentrySpanStatusV2? status}) {}

  @override
  SentrySpanV2 startIdleSpan(
    String name, {
    SentrySpanV2? parentSpan = const UnsetSentrySpanV2(),
    Duration idleTimeout = const Duration(milliseconds: 1000),
    Duration childSpanTimeout = const Duration(milliseconds: 15000),
    Duration finalTimeout = const Duration(milliseconds: 30000),
    bool trimIdleSpanEndTimestamp = true,
    Map<String, SentryAttribute>? attributes,
  }) =>
      NoOpSentrySpanV2.instance;

  @override
  RecordingSentrySpanV2? fallbackRootSpan;
}
