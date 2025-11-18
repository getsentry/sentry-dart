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
}
