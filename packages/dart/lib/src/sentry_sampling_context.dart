import 'package:meta/meta.dart';

import '../sentry.dart';
import 'telemetry/span/sentry_span_sampling_context.dart';

/// Context used by [TracesSamplerCallback] to determine if transaction
/// is going to be sampled.
@immutable
class SentrySamplingContext {
  final SentryTransactionContext _transactionContext;
  final SentrySpanSamplingContextV2 _spanContext;
  final Map<String, dynamic> _customSamplingContext;
  final SentryTraceLifecycle _traceLifecycle;

  /// Placeholder for streaming mode where transaction context is not used.
  static final _unusedTransactionContext =
      SentryTransactionContext('unused', 'unused');

  /// Placeholder for static mode where span context is not used.
  static final _unusedSpanContext = SentrySpanSamplingContextV2('unused', {});

  SentrySamplingContext(
      this._transactionContext, this._spanContext, this._traceLifecycle,
      {Map<String, dynamic>? customSamplingContext})
      : _customSamplingContext = customSamplingContext ?? {};

  /// Creates a sampling context for SpanV2 (streaming mode).
  ///
  /// In streaming mode, the transaction context is not used - only the
  /// span context matters for sampling decisions.
  SentrySamplingContext.forSpanV2(SentrySpanSamplingContextV2 spanContext)
      : _transactionContext = _unusedTransactionContext,
        _spanContext = spanContext,
        _traceLifecycle = SentryTraceLifecycle.streaming,
        _customSamplingContext = {};

  /// Creates a sampling context for legacy transactions (static mode).
  ///
  /// In static mode, the span context is not used - only the transaction
  /// context matters for sampling decisions.
  SentrySamplingContext.forTransaction(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
  })  : _transactionContext = transactionContext,
        _spanContext = _unusedSpanContext,
        _traceLifecycle = SentryTraceLifecycle.static,
        _customSamplingContext = customSamplingContext ?? {};

  /// The Transaction context
  SentryTransactionContext get transactionContext {
    assert(_traceLifecycle == SentryTraceLifecycle.static,
        'Transaction sampling context is only available in static mode');
    return _transactionContext;
  }

  /// The Span V2 sampling context
  SentrySpanSamplingContextV2 get spanContext {
    assert(_traceLifecycle == SentryTraceLifecycle.streaming,
        'Span sampling context is only available in streaming mode');
    return _spanContext;
  }

  /// The given sampling context
  Map<String, dynamic> get customSamplingContext =>
      Map.unmodifiable(_customSamplingContext);

  /// The trace lifecycle mode for this sampling context.
  SentryTraceLifecycle get traceLifecycle => _traceLifecycle;
}
