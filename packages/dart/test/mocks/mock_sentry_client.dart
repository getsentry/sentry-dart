import 'dart:async';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';

import 'no_such_method_provider.dart';

class MockSentryClient with NoSuchMethodProvider implements SentryClient {
  List<CaptureEventCall> captureEventCalls = [];
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<CaptureMessageCall> captureMessageCalls = [];
  List<CaptureEnvelopeCall> captureEnvelopeCalls = [];
  List<CaptureTransactionCall> captureTransactionCalls = [];
  List<CaptureFeedbackCall> captureFeedbackCalls = [];
  List<CaptureLogCall> captureLogCalls = [];
  List<CaptureMetricCall> captureMetricCalls = [];
  int closeCalls = 0;

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope? scope,
    dynamic stackTrace,
    Hint? hint,
  }) async {
    captureEventCalls.add(CaptureEventCall(
      event,
      scope,
      stackTrace,
      hint,
    ));
    return event.eventId;
  }

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Scope? scope,
    Hint? hint,
  }) async {
    captureExceptionCalls.add(CaptureExceptionCall(
      throwable,
      stackTrace,
      scope,
      hint,
    ));
    return SentryId.newId();
  }

  @override
  Future<SentryId> captureMessage(
    String? formatted, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List? params,
    Scope? scope,
    Hint? hint,
  }) async {
    captureMessageCalls.add(CaptureMessageCall(
      formatted,
      level,
      template,
      params,
      scope,
      hint,
    ));
    return SentryId.newId();
  }

  @override
  Future<SentryId> captureEnvelope(SentryEnvelope envelope) async {
    captureEnvelopeCalls.add(CaptureEnvelopeCall(envelope));
    return envelope.header.eventId ?? SentryId.newId();
  }

  @override
  Future<SentryId> captureFeedback(
    SentryFeedback feedback, {
    Scope? scope,
    Hint? hint,
  }) async {
    captureFeedbackCalls.add(CaptureFeedbackCall(
      feedback,
      scope,
      hint,
    ));
    return SentryId.newId();
  }

  @override
  FutureOr<void> captureLog(SentryLog log, {Scope? scope}) async {
    captureLogCalls.add(CaptureLogCall(log, scope));
  }

  @override
  Future<void> captureMetric(SentryMetric metric, {Scope? scope}) async {
    captureMetricCalls.add(CaptureMetricCall(metric, scope));
  }

  @override
  void close() {
    closeCalls = closeCalls + 1;
  }

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
    Hint? hint,
  }) async {
    captureTransactionCalls
        .add(CaptureTransactionCall(transaction, traceContext, hint));
    return transaction.eventId;
  }
}

class CaptureEventCall {
  final SentryEvent event;
  final Scope? scope;
  final dynamic stackTrace;
  final Hint? hint;

  CaptureEventCall(
    this.event,
    this.scope,
    this.stackTrace,
    this.hint,
  );
}

class CaptureFeedbackCall {
  final SentryFeedback feedback;
  final Hint? hint;
  final Scope? scope;

  CaptureFeedbackCall(
    this.feedback,
    this.scope,
    this.hint,
  );
}

class CaptureExceptionCall {
  final dynamic throwable;
  final dynamic stackTrace;
  final Scope? scope;
  final Hint? hint;

  CaptureExceptionCall(
    this.throwable,
    this.stackTrace,
    this.scope,
    this.hint,
  );
}

class CaptureMessageCall {
  final String? formatted;
  final SentryLevel? level;
  final String? template;
  final List? params;
  final Scope? scope;
  final Hint? hint;

  CaptureMessageCall(
    this.formatted,
    this.level,
    this.template,
    this.params,
    this.scope,
    this.hint,
  );
}

class CaptureEnvelopeCall {
  final SentryEnvelope envelope;

  CaptureEnvelopeCall(this.envelope);
}

class CaptureTransactionCall {
  final SentryTransaction transaction;
  final SentryTraceContextHeader? traceContext;
  final Hint? hint;

  CaptureTransactionCall(this.transaction, this.traceContext, this.hint);
}

class CaptureLogCall {
  final SentryLog log;
  final Scope? scope;

  CaptureLogCall(this.log, this.scope);
}

class CaptureMetricCall {
  final SentryMetric metric;
  final Scope? scope;

  CaptureMetricCall(this.metric, this.scope);
}
