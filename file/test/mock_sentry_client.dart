import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

class MockSentryClient with NoSuchMethodProvider implements SentryClient {
  List<CaptureTransactionCall> captureTransactionCalls = [];

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
  }) async {
    captureTransactionCalls
        .add(CaptureTransactionCall(transaction, traceContext));
    return transaction.eventId;
  }
}

class CaptureTransactionCall {
  final SentryTransaction transaction;
  final SentryTraceContextHeader? traceContext;

  CaptureTransactionCall(this.transaction, this.traceContext);
}
