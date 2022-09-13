import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_baggage.dart';
import 'tracing.dart';

@immutable
class SentryTransactionContext extends SentrySpanContext {
  final String name;
  final SentryTracesSamplingDecision? parentTracesSamplingDecision;
  final SentryTransactionNameSource? transactionNameSource;
  final SentryTracesSamplingDecision? tracesSamplingDecision;

  SentryTransactionContext(
    this.name,
    String operation, {
    String? description,
    this.parentTracesSamplingDecision,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    this.transactionNameSource,
    this.tracesSamplingDecision,
  }) : super(
          operation: operation,
          description: description,
          traceId: traceId,
          spanId: spanId,
          parentSpanId: parentSpanId,
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
      parentTracesSamplingDecision: traceHeader.sampled != null
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
    SentryTracesSamplingDecision? parentTracesSamplingDecision,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    SentryTransactionNameSource? transactionNameSource,
    SentryTracesSamplingDecision? tracesSamplingDecision,
  }) =>
      SentryTransactionContext(
        name ?? this.name,
        operation ?? this.operation,
        description: description ?? this.description,
        parentTracesSamplingDecision:
            parentTracesSamplingDecision ?? this.parentTracesSamplingDecision,
        traceId: traceId ?? this.traceId,
        spanId: spanId ?? this.spanId,
        parentSpanId: parentSpanId ?? this.parentSpanId,
        transactionNameSource:
            transactionNameSource ?? this.transactionNameSource,
        tracesSamplingDecision:
            tracesSamplingDecision ?? this.tracesSamplingDecision,
      );
}
