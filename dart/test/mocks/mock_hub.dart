import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_hub.dart';
import 'package:sentry/src/sentry_user_feedback.dart';

class MockHub implements Hub {
  List<CaptureEventCall> captureEventCalls = [];
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<CaptureMessageCall> captureMessageCalls = [];
  List<AddBreadcrumbCall> addBreadcrumbCalls = [];
  List<SentryClient?> bindClientCalls = [];
  List<SentryUserFeedback> userFeedbackCalls = [];
  int closeCalls = 0;
  bool _isEnabled = true;
  int spanContextCals = 0;

  /// Useful for tests.
  void reset() {
    captureEventCalls = [];
    captureExceptionCalls = [];
    captureMessageCalls = [];
    addBreadcrumbCalls = [];
    bindClientCalls = [];
    closeCalls = 0;
    _isEnabled = true;
    spanContextCals = 0;
  }

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    addBreadcrumbCalls.add(AddBreadcrumbCall(crumb, hint));
  }

  @override
  void bindClient(SentryClient client) {
    bindClientCalls.add(client);
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    captureEventCalls.add(CaptureEventCall(
      event,
      stackTrace,
      hint,
    ));
    return event.eventId;
  }

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    captureExceptionCalls.add(CaptureExceptionCall(
      throwable,
      stackTrace,
      hint,
    ));
    return SentryId.newId();
  }

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    captureMessageCalls.add(CaptureMessageCall(
      message,
      level,
      template,
      params,
      hint,
    ));
    return SentryId.newId();
  }

  @override
  Hub clone() {
    return NoOpHub();
  }

  @override
  Future<void> close() async {
    closeCalls = closeCalls + 1;
    _isEnabled = false;
  }

  @override
  void configureScope(callback) {}

  @override
  bool get isEnabled => _isEnabled;

  @override
  SentryId get lastEventId => SentryId.empty();

  @override
  Future<SentryId> captureTransaction(SentryTransaction transaction) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureUserFeedback(SentryUserFeedback userFeedback) async {
    userFeedbackCalls.add(userFeedback);
    return SentryId.empty();
  }

  @override
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    bool? bindToScope,
    Map<String, dynamic>? customSamplingContext,
  }) {
    return NoOpSentrySpan();
  }

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    bool? bindToScope,
  }) {
    return NoOpSentrySpan();
  }

  @override
  ISentrySpan? getSpan() {
    return null;
  }

  @override
  void setSpanContext(throwable, ISentrySpan span, String transaction) {
    spanContextCals++;
  }
}

class CaptureEventCall {
  final SentryEvent event;
  final dynamic stackTrace;
  final dynamic hint;

  CaptureEventCall(this.event, this.stackTrace, this.hint);
}

class CaptureExceptionCall {
  final dynamic throwable;
  final dynamic stackTrace;
  final dynamic hint;

  CaptureExceptionCall(
    this.throwable,
    this.stackTrace,
    this.hint,
  );
}

class CaptureMessageCall {
  final String? message;
  final SentryLevel? level;
  final String? template;
  final List? params;
  final dynamic hint;

  CaptureMessageCall(
    this.message,
    this.level,
    this.template,
    this.params,
    this.hint,
  );
}

class AddBreadcrumbCall {
  final Breadcrumb crumb;
  final dynamic hint;

  AddBreadcrumbCall(this.crumb, this.hint);
}
