import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../test_utils.dart';
import 'mock_sentry_client.dart';
import 'no_such_method_provider.dart';

class MockHub with NoSuchMethodProvider implements Hub {
  List<CaptureEventCall> captureEventCalls = [];
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<CaptureMessageCall> captureMessageCalls = [];
  List<AddBreadcrumbCall> addBreadcrumbCalls = [];
  List<CaptureLogCall> captureLogCalls = [];
  List<SentryClient?> bindClientCalls = [];
  List<CaptureSpanCall> captureSpanCalls = [];

  // ignore: deprecated_member_use_from_same_package
  List<CaptureTransactionCall> captureTransactionCalls = [];
  int closeCalls = 0;
  bool _isEnabled = true;
  int spanContextCals = 0;
  int getSpanCalls = 0;

  final _options = defaultTestOptions();

  late Scope _scope;

  @override
  @internal
  SentryOptions get options => _options;

  MockHub() {
    _scope = Scope(_options);
  }

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
    captureTransactionCalls = [];
    getSpanCalls = 0;
    _scope = Scope(_options);
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
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
    Hint? hint,
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
    Hint? hint,
    SentryMessage? message,
    ScopeCallback? withScope,
  }) async {
    captureExceptionCalls.add(CaptureExceptionCall(
      throwable,
      stackTrace,
      hint,
      message,
    ));
    return SentryId.newId();
  }

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level = SentryLevel.info,
    String? template,
    List? params,
    Hint? hint,
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
  FutureOr<void> captureLog(SentryLog log) async {
    captureLogCalls.add(CaptureLogCall(log, null));
  }

  @override
  void captureSpan(SentrySpanV2 span) {
    captureSpanCalls.add(CaptureSpanCall(span));
  }

  @override
  Future<void> close() async {
    closeCalls = closeCalls + 1;
    _isEnabled = false;
  }

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    SentryTraceContextHeader? traceContext,
    Hint? hint,
  }) async {
    captureTransactionCalls
        .add(CaptureTransactionCall(transaction, traceContext, hint));
    return transaction.eventId;
  }

  @override
  ISentrySpan? getSpan() {
    getSpanCalls++;
    return null;
  }

  @override
  void setSpanContext(throwable, ISentrySpan span, String transaction) {
    spanContextCals++;
  }

  @override
  Scope get scope => _scope;
}

class CaptureEventCall {
  final SentryEvent event;
  final dynamic stackTrace;
  final Hint? hint;

  CaptureEventCall(this.event, this.stackTrace, this.hint);
}

class CaptureExceptionCall {
  final dynamic throwable;
  final dynamic stackTrace;
  final Hint? hint;
  final SentryMessage? message;

  CaptureExceptionCall(
    this.throwable,
    this.stackTrace,
    this.hint,
    this.message,
  );
}

class CaptureMessageCall {
  final String? message;
  final SentryLevel? level;
  final String? template;
  final List? params;
  final Hint? hint;

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
  final Hint? hint;

  AddBreadcrumbCall(this.crumb, this.hint);
}

class CaptureSpanCall {
  final SentrySpanV2 span;

  CaptureSpanCall(this.span);
}
