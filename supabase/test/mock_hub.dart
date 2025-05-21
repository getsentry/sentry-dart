import 'package:sentry/sentry.dart';

class MockHub implements Hub {
  MockHub(this._options);

  final SentryOptions _options;

  @override
  SentryOptions get options => _options;

  // Breadcrumb

  final addBreadcrumbCalls = <(Breadcrumb, Hint?)>[];

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    addBreadcrumbCalls.add((crumb, hint));
  }

  // Transaction

  final startTransactionCalls = <(String, String)>[];
  var mockSpan = _MockSpan();

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
  }) {
    startTransactionCalls.add((name, operation));
    return mockSpan;
  }

  // Error

  final captureEventCalls = <(SentryEvent, dynamic, Hint?, ScopeCallback?)>[];

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) {
    captureEventCalls.add((event, stackTrace, hint, withScope));
    return Future.value(SentryId.empty());
  }

  // No such method
  @override
  void noSuchMethod(Invocation invocation) {
    'Method ${invocation.memberName} was called '
        'with arguments ${invocation.positionalArguments}';
  }
}

class _MockSpan implements ISentrySpan {
  var data = <String, dynamic>{};
  var finishCalls = <(SpanStatus?, DateTime?, Hint?)>[];

  var setThrowableCalls = <dynamic>[];
  var setStatusCalls = <SpanStatus?>[];

  @override
  void setData(String key, dynamic value) {
    data[key] = value;
  }

  @override
  set throwable(dynamic value) {
    setThrowableCalls.add(value);
  }

  @override
  set status(SpanStatus? value) {
    setStatusCalls.add(value);
  }

  @override
  Future<void> finish(
      {SpanStatus? status, DateTime? endTimestamp, Hint? hint}) {
    finishCalls.add((status, endTimestamp, hint));
    return Future.value();
  }

  // No such method
  @override
  void noSuchMethod(Invocation invocation) {
    'Method ${invocation.memberName} was called '
        'with arguments ${invocation.positionalArguments}';
  }
}
