import 'package:meta/meta.dart';

import 'protocol.dart';
import 'tracing.dart';

@immutable
class SentryTransactionContext extends SentrySpanContext {
  final String name;
  final bool? parentSampled;
  final bool? sampled;
  final SentryTransactionNameSource? transactionNameSource;

  SentryTransactionContext(
    this.name,
    String operation, {
    String? description,
    this.sampled,
    this.parentSampled,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    this.transactionNameSource,
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
  }) {
    return SentryTransactionContext(
      name,
      operation,
      traceId: traceHeader.traceId,
      parentSpanId: traceHeader.spanId,
      parentSampled: traceHeader.sampled,
      transactionNameSource:
          transactionNameSource ?? SentryTransactionNameSource.custom,
    );
  }

  SentryTransactionContext copyWith({
    String? name,
    String? operation,
    String? description,
    bool? sampled,
    bool? parentSampled,
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    SentryTransactionNameSource? transactionNameSource,
  }) =>
      SentryTransactionContext(
        name ?? this.name,
        operation ?? this.operation,
        description: description ?? this.description,
        sampled: sampled ?? this.sampled,
        parentSampled: parentSampled ?? this.parentSampled,
        traceId: traceId ?? this.traceId,
        spanId: spanId ?? this.spanId,
        parentSpanId: parentSpanId ?? this.parentSpanId,
        transactionNameSource:
            transactionNameSource ?? this.transactionNameSource,
      );
}
