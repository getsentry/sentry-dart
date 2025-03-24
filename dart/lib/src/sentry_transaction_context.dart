import 'protocol.dart';
import 'sentry_baggage.dart';
import 'sentry_trace_origins.dart';
import 'tracing.dart';

class SentryTransactionContext extends SentrySpanContext {
  String name;
  SentryTransactionNameSource? transactionNameSource;
  SentryTracesSamplingDecision? samplingDecision;
  SentryTracesSamplingDecision? parentSamplingDecision;

  SentryTransactionContext(
    this.name,
    String operation, {
    super.description,
    super.traceId,
    super.spanId,
    super.parentSpanId,
    this.transactionNameSource,
    this.samplingDecision,
    this.parentSamplingDecision,
    super.origin,
  }) : super(
          operation: operation,
        );

  factory SentryTransactionContext.fromSentryTrace(
    String name,
    String operation,
    SentryTraceHeader traceHeader, {
    SentryTransactionNameSource? transactionNameSource,
    SentryBaggage? baggage,
  }) {
    final sampleRate = baggage?.getSampleRate();
    final sampleRand = baggage?.getSampleRand();
    return SentryTransactionContext(
      name,
      operation,
      traceId: traceHeader.traceId,
      parentSpanId: traceHeader.spanId,
      parentSamplingDecision: traceHeader.sampled != null
          ? SentryTracesSamplingDecision(
              traceHeader.sampled!,
              sampleRate: sampleRate,
              sampleRand: sampleRand,
            )
          : null,
      transactionNameSource:
          transactionNameSource ?? SentryTransactionNameSource.custom,
      origin: SentryTraceOrigins.manual,
    );
  }

  SentryTransactionContext copyWith({
    String? name,
    String? operation,
    String? description,
    SentryTracesSamplingDecision? parentSamplingDecision,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    SentryTransactionNameSource? transactionNameSource,
    SentryTracesSamplingDecision? samplingDecision,
    String? origin,
  }) =>
      SentryTransactionContext(
        name ?? this.name,
        operation ?? this.operation,
        description: description ?? this.description,
        parentSamplingDecision:
            parentSamplingDecision ?? this.parentSamplingDecision,
        traceId: traceId ?? this.traceId,
        spanId: spanId ?? this.spanId,
        parentSpanId: parentSpanId ?? this.parentSpanId,
        transactionNameSource:
            transactionNameSource ?? this.transactionNameSource,
        samplingDecision: samplingDecision ?? this.samplingDecision,
        origin: origin ?? this.origin,
      );
}
