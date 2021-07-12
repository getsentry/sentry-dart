import 'dart:async';

import 'package:meta/meta.dart';
import 'sentry_trace_header.dart';
import 'span_interface.dart';
import 'sentry_transaction.dart';
import '../utils.dart';

import '../hub.dart';
import 'sentry_id.dart';
import 'span_id.dart';
import 'span_status.dart';

class SentrySpan extends SpanInterface with SpanMixin {
  SentrySpan({
    DateTime? start,
    required this.transaction,
    required this.hub,
    required this.context,
  }) : start = start ?? getUtcDateTime();

  @override
  final DateTime start;
  @override
  DateTime? end;
  @override
  SentrySpanContext context;

  final SentryTransaction transaction;
  final Hub hub;

  SentrySpan startChild({
    String? description,
    DateTime? start,
  }) {
    return transaction.startChild(
      parentId: context.spanId,
      operation: context.operation,
      description: description ?? context.description,
      start: start,
    );
  }

  @override
  FutureOr<void> finish({
    SpanStatus? status,
    DateTime? end,
  }) {
    this.end = end ?? getUtcDateTime();
    context = context.copySpanContextWith(
      status: status,
    );
  }

  @override
  SentryTraceHeader toSentryTrace() {
    return SentryTraceHeader(
      context.traceId,
      context.spanId,
      context.isSampled,
    );
  }

  Map<String, dynamic> toJson() {
    final json = context.toJson();
    json['start_timestamp'] = formatDateAsIso8601WithMillisPrecision(start);
    if (end != null) {
      json['timestamp'] = formatDateAsIso8601WithMillisPrecision(end!);
    }
    return json;
  }
}

@immutable
class SentrySpanContext {
  static const type = 'trace';

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
  /// Longer description of the span's operation, which uniquely identifies the
  /// span but is consistent across instances of the span.
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

  factory SentrySpanContext.fromJson(Map<String, dynamic> json) {
    return SentrySpanContext(
        operation: json['op'] as String,
        spanId: SpanId.fromId(['span_id'] as String),
        parentSpanId: json['parent_span_id'] == null
            ? null
            : SpanId.fromId(json['parent_span_id'] as String),
        traceId: json['trace_id'] == null
            ? null
            : SentryId.fromId(json['trace_id'] as String),
        description: json['description'] as String?,
        status: json['status'] == null
            ? null
            : SpanStatus.fromString(json['status'] as String),
        tags: json['tags'] as Map<String, String>);
  }

  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId?.toString(),
      if (description != null) 'description': description,
      if (status != null) 'status': status!.toString(),
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
    };
  }

  SentrySpanContext clone() => SentrySpanContext(
        operation: operation,
        traceId: traceId,
        spanId: spanId,
        description: description,
        status: status,
        tags: tags,
        parentSpanId: parentSpanId,
        isSampled: isSampled,
      );

  SentrySpanContext copySpanContextWith({SpanStatus? status}) {
    return SentrySpanContext(
      operation: operation,
      status: status ?? this.status,
      description: description,
      isSampled: isSampled,
      parentSpanId: parentSpanId,
      spanId: spanId,
      tags: tags,
      traceId: traceId,
    );
  }
}
