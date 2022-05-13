import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

class MockSentryClient with NoSuchMethodProvider implements SentryClient {
  List<CaptureEventCall> captureEventCalls = [];
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<CaptureMessageCall> captureMessageCalls = [];
  List<CaptureEnvelopeCall> captureEnvelopeCalls = [];
  List<CaptureTransactionCall> captureTransactionCalls = [];
  List<SentryUserFeedback> userFeedbackCalls = [];
  int closeCalls = 0;

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope? scope,
    dynamic stackTrace,
    dynamic hint,
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
    dynamic hint,
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
    dynamic hint,
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
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {
    userFeedbackCalls.add(userFeedback);
  }

  @override
  void close() {
    closeCalls = closeCalls + 1;
  }

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
  }) async {
    captureTransactionCalls.add(CaptureTransactionCall(transaction));
    return transaction.eventId;
  }
}

class CaptureEventCall {
  final SentryEvent event;
  final Scope? scope;
  final dynamic stackTrace;
  final dynamic hint;

  CaptureEventCall(
    this.event,
    this.scope,
    this.stackTrace,
    this.hint,
  );
}

class CaptureExceptionCall {
  final dynamic throwable;
  final dynamic stackTrace;
  final Scope? scope;
  final dynamic hint;

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
  final dynamic hint;

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

  CaptureTransactionCall(this.transaction);
}
