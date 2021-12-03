import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_hub.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

class MockHub implements Hub {
  final List<Breadcrumb> breadcrumbs = [];
  final List<CapturedEvents> events = [];

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    breadcrumbs.add(crumb);
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    events.add(CapturedEvents(event, stackTrace));
    return SentryId.newId();
  }

  // everything below is not needed

  @override
  void bindClient(SentryClient client) {}

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureTransaction(SentryTransaction transaction) async =>
      SentryId.empty();

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {}

  @override
  Hub clone() => NoOpHub();

  @override
  Future<void> close() async {}

  @override
  void configureScope(ScopeCallback callback) {}

  @override
  ISentrySpan? getSpan() => NoOpSentrySpan();

  @override
  bool get isEnabled => false;

  @override
  SentryId get lastEventId => SentryId.empty();

  @override
  void setSpanContext(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) {}

  @override
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    bool? bindToScope,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      NoOpSentrySpan();

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    bool? bindToScope,
  }) =>
      NoOpSentrySpan();
}

class CapturedEvents {
  CapturedEvents(this.event, this.stackTrace);

  final SentryEvent event;
  final dynamic stackTrace;
}
