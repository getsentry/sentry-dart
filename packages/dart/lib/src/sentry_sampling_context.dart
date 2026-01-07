import 'package:meta/meta.dart';

import '../sentry.dart';
import 'telemetry/span/sentry_span_sampling_context.dart';

/// Context used by [TracesSamplerCallback] to determine if transaction
/// is going to be sampled.
///
/// Note: This class currently supports both static (transaction-based) and
/// streaming (span-based) modes for backwards compatibility. The dual-mode
/// design with placeholder values and runtime checks is a temporary solution.
/// Once the legacy transaction API is removed, this class should be simplified
/// to only support the streaming mode with [SentrySpanSamplingContextV2].
@immutable
class SentrySamplingContext {
  final SentryTransactionContext _transactionContext;
  final SentrySpanSamplingContextV2 _spanContext;
  final Map<String, dynamic> _customSamplingContext;
  final SentryTraceLifecycle _traceLifecycle;

  // TODO: Remove these placeholders once legacy transaction API is removed.

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

  /// The Transaction context.
  ///
  /// Throws [StateError] if accessed in streaming mode.
  ///
  /// TODO: Remove this getter once legacy transaction API is removed.
  /// This runtime check is a temporary solution for backwards compatibility.
  SentryTransactionContext get transactionContext {
    if (_traceLifecycle != SentryTraceLifecycle.static) {
      throw StateError('transactionContext is only available in static mode. '
          'Use spanContext for streaming mode.');
    }
    return _transactionContext;
  }

  /// The Span V2 sampling context.
  ///
  /// Throws [StateError] if accessed in static mode.
  ///
  /// TODO: Remove the runtime check once legacy transaction API is removed.
  /// This runtime check is a temporary solution for backwards compatibility.
  SentrySpanSamplingContextV2 get spanContext {
    if (_traceLifecycle != SentryTraceLifecycle.streaming) {
      throw StateError('spanContext is only available in streaming mode. '
          'Use transactionContext for static mode.');
    }
    return _spanContext;
  }

  /// The given sampling context
  Map<String, dynamic> get customSamplingContext =>
      Map.unmodifiable(_customSamplingContext);

  /// The trace lifecycle mode for this sampling context.
  SentryTraceLifecycle get traceLifecycle => _traceLifecycle;
}
