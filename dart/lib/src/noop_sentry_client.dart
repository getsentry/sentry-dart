import 'dart:async';

import 'hint.dart';
import 'protocol.dart';
import 'protocol/sentry_feedback.dart';
import 'scope.dart';
import 'sdk_lifecycle_hooks.dart';
import 'sentry_client.dart';
import 'sentry_envelope.dart';
import 'sentry_options.dart';
import 'sentry_trace_context_header.dart';

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
  Future<void> close() async {}

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
    Hint? hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureFeedback(SentryFeedback feedback,
          {Scope? scope, Hint? hint}) async =>
      SentryId.empty();

  @override
  FutureOr<void> captureLog(SentryLog log, {Scope? scope}) async {}

  final _lifeCycleRegistry = SdkLifecycleRegistry(SentryOptions.empty());

  @override
  SdkLifecycleRegistry get lifeCycleRegistry => _lifeCycleRegistry;
}
