import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_baggage.dart';
import 'tracing.dart';

@immutable
class SentryTransactionContext extends SentrySpanContext {
  final String name;
  final SentryTracesSamplingDecision? parentSamplingDecision;
  final SentryTransactionNameSource? transactionNameSource;
  final SentryTracesSamplingDecision? samplingDecision;

  SentryTransactionContext(
    this.name,
    String operation, {
    String? description,
    this.parentSamplingDecision,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    this.transactionNameSource,
    this.samplingDecision,
    String? origin,
  }) : super(
          operation: operation,
          description: description,
          traceId: traceId,
          spanId: spanId,
          parentSpanId: parentSpanId,
          origin: origin,
        );

  factory SentryTransactionContext.fromSentryTrace(
    String name,
    String operation,
    SentryTraceHeader traceHeader, {
    SentryTransactionNameSource? transactionNameSource,
    SentryBaggage? baggage,
  }) {
    final sampleRate = baggage?.getSampleRate();
    return SentryTransactionContext(
      name,
      operation,
      traceId: traceHeader.traceId,
      parentSpanId: traceHeader.spanId,
      parentSamplingDecision: traceHeader.sampled != null
          ? SentryTracesSamplingDecision(
              traceHeader.sampled!,
              sampleRate: sampleRate,
            )
          : null,
      transactionNameSource:
          transactionNameSource ?? SentryTransactionNameSource.custom,
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
      );
}
