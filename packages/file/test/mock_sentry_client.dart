import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

SentryOptions defaultTestOptions() {
  // ignore: invalid_use_of_internal_member
  return SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
}

class MockSentryClient with NoSuchMethodProvider implements SentryClient {
  List<CaptureTransactionCall> captureTransactionCalls = [];

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
    Hint? hint,
  }) async {
    captureTransactionCalls
        .add(CaptureTransactionCall(transaction, scope, traceContext, hint));
    return transaction.eventId;
  }
}

class CaptureTransactionCall {
  final SentryTransaction transaction;
  final Scope? scope;
  final SentryTraceContextHeader? traceContext;
  final Hint? hint;

  CaptureTransactionCall(
      this.transaction, this.scope, this.traceContext, this.hint);
}
