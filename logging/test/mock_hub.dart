import 'package:sentry/sentry.dart';

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
  }) {
    // TODO: implement captureException
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) {
    // TODO: implement captureMessage
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureTransaction(SentryTransaction transaction) {
    // TODO: implement captureTransaction
    throw UnimplementedError();
  }

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) {
    // TODO: implement captureUserFeedback
    throw UnimplementedError();
  }

  @override
  Hub clone() {
    // TODO: implement clone
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  void configureScope(ScopeCallback callback) {
    // TODO: implement configureScope
  }

  @override
  ISentrySpan? getSpan() {
    // TODO: implement getSpan
    throw UnimplementedError();
  }

  @override
  // TODO: implement isEnabled
  bool get isEnabled => throw UnimplementedError();

  @override
  // TODO: implement lastEventId
  SentryId get lastEventId => throw UnimplementedError();

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
  }) {
    throw UnimplementedError();
  }

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    bool? bindToScope,
  }) {
    throw UnimplementedError();
  }
}

class CapturedEvents {
  CapturedEvents(this.event, this.stackTrace);

  final SentryEvent event;
  final dynamic stackTrace;
}
