import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/metrics/metrics_aggregator.dart';

import '../mocks.dart';
import 'mock_sentry_client.dart';
import 'no_such_method_provider.dart';

class MockHub with NoSuchMethodProvider implements Hub {
  List<CaptureEventCall> captureEventCalls = [];
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<CaptureMessageCall> captureMessageCalls = [];
  List<AddBreadcrumbCall> addBreadcrumbCalls = [];
  List<SentryClient?> bindClientCalls = [];
  List<SentryUserFeedback> userFeedbackCalls = [];
  List<CaptureTransactionCall> captureTransactionCalls = [];
  List<CaptureMetricsCall> captureMetricsCalls = [];
  int closeCalls = 0;
  bool _isEnabled = true;
  int spanContextCals = 0;
  int getSpanCalls = 0;

  final _options = SentryOptions(dsn: fakeDsn);
  late final MetricsAggregator _metricsAggregator =
      MetricsAggregator(options: _options, hub: this);

  @override
  @internal
  SentryOptions get options => _options;

  @override
  MetricsAggregator? get metricsAggregator => _metricsAggregator;

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
    captureMetricsCalls = [];
    getSpanCalls = 0;
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
  }) async {
    captureTransactionCalls
        .add(CaptureTransactionCall(transaction, traceContext));
    return transaction.eventId;
  }

  @override
  Future<SentryId> captureMetrics(
      Map<int, Iterable<Metric>> metricsBuckets) async {
    captureMetricsCalls.add(CaptureMetricsCall(metricsBuckets));
    return SentryId.newId();
  }

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {
    userFeedbackCalls.add(userFeedback);
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
  Scope get scope => Scope(_options);
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
