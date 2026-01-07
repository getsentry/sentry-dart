import 'package:meta/meta.dart';

import '../sentry.dart';
import 'telemetry/span/sentry_span_sampling_context.dart';
import 'tracing.dart';
import 'sentry_options.dart';

/// Context used by [TracesSamplerCallback] to determine if transaction
/// is going to be sampled.
@immutable
class SentrySamplingContext {
  final SentryTransactionContext _transactionContext;
  final SentrySpanSamplingContextV2 _spanContext;
  final Map<String, dynamic> _customSamplingContext;
  final SentryTraceLifecycle _traceLifecycle;

  SentrySamplingContext(
      this._transactionContext, this._spanContext, this._traceLifecycle,
      {Map<String, dynamic>? customSamplingContext})
      : _customSamplingContext = customSamplingContext ?? {};

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
}
