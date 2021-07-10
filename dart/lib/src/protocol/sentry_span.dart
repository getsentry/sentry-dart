import 'package:meta/meta.dart';
import 'sentry_trace_header.dart';
import 'span_interface.dart';
import 'sentry_transaction.dart';
import '../utils.dart';

import '../hub.dart';
import 'sentry_id.dart';
import 'span_id.dart';
import 'span_status.dart';

class SentrySpan implements SpanInterface {
  SentrySpan({
    DateTime? start,
    required this.transaction,
    required this.hub,
    required this.context,
  }) : start = start ?? getUtcDateTime();

  final DateTime start;
  DateTime? end;
  SentrySpanContext context;
  final SentryTransaction transaction;
  final Hub hub;
  bool get finished => end != null;

  SentrySpan startChild({
    required String operation,
    String? description,
    DateTime? start,
  }) {
    return transaction.startChild(
      parentId: context.spanId,
      operation: operation,
      description: description ?? context.description,
      start: start,
    );
  }

  void finish({SpanStatus? status}) {
    end = getUtcDateTime();
    context = context.copyWith(
      status: status,
    );
  }

  SentryTraceHeader toSentryTrace() {
    return SentryTraceHeader(
        context.traceId, context.spanId, context.isSampled);
  }
}

@immutable
class SentrySpanContext {
  SentrySpanContext({
    required this.operation,
    SentryId? traceId,
    SpanId? spanId,
    this.description,
    this.status,
    this.tags,
    this.parentSpanId,
    this.isSampled,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();

  /// Span description.
  /// Longer description of the span's operation, which uniquely identifies the span but is
  /// consistent across instances of the span.
  final String? description;

  /// Span operation.
  /// Short code identifying the type of operation the span is measuring.
  final String operation;

  /// Span status.
  final SpanStatus? status;

  /// Determines which trace the Span belongs to.
  final SentryId traceId;

  /// Span Id
  final SpanId spanId;

  /// Id of a parent span
  final SpanId? parentSpanId;

  /// If trace is sampled.
  final bool? isSampled;

  final Map<String, String>? tags;

  SentrySpanContext copyWith({
    SpanStatus? status,
  }) {
    return SentrySpanContext(
      operation: operation,
      status: status ?? this.status,
    );
  }
}
