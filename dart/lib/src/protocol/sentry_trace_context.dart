import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../propagation_context.dart';
import '../protocol.dart';
import 'unknown.dart';

@immutable
class SentryTraceContext {
  static const String type = 'trace';

  /// Determines which trace the Span belongs to
  late final SentryId traceId;

  /// Span id
  late final SpanId spanId;

  /// Id of a parent span
  final SpanId? parentSpanId;

  /// Whether the span is sampled or not
  final bool? sampled;

  /// Short code identifying the type of operation the span is measuring
  final String operation;

  /// Longer description of the span's operation, which uniquely identifies the span but is
  /// consistent across instances of the span.
  final String? description;

  /// The Span status
  final SpanStatus? status;

  /// The origin of the span indicates what created the span.
  ///
  /// @note Gets set by the SDK. It is not expected to be set manually by users.
  ///
  /// @see <https://develop.sentry.dev/sdk/performance/trace-origin>
  final String? origin;

  @internal
  final Map<String, dynamic>? unknown;

  factory SentryTraceContext.fromJson(Map<String, dynamic> json) {
    return SentryTraceContext(
      operation: json['op'] as String,
      spanId: SpanId.fromId(json['span_id'] as String),
      parentSpanId: json['parent_span_id'] == null
          ? null
          : SpanId.fromId(json['parent_span_id'] as String),
      traceId: SentryId.fromId(json['trace_id'] as String),
      description: json['description'] as String?,
      status: json['status'] == null
          ? null
          : SpanStatus.fromString(json['status'] as String),
      sampled: true,
      origin: json['origin'] == null ? null : json['origin'] as String?,
      unknown: unknownFrom(json, {
        'op',
        'span_id',
        'parent_span_id',
        'trace_id',
        'description',
        'status',
        'origin',
      }),
    );
  }

  /// Item encoded as JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId!.toString(),
      if (description != null) 'description': description,
      if (status != null) 'status': status!.toString(),
      if (origin != null) 'origin': origin,
    };
    if (unknown != null) {
      json.addAll(unknown ?? {});
    }
    return json;
  }

  SentryTraceContext clone() => SentryTraceContext(
        operation: operation,
        traceId: traceId,
        spanId: spanId,
        description: description,
        status: status,
        parentSpanId: parentSpanId,
        sampled: sampled,
        origin: origin,
        unknown: unknown,
      );

  SentryTraceContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentSpanId,
    this.sampled,
    required this.operation,
    this.description,
    this.status,
    this.origin,
    this.unknown,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();

  @internal
  factory SentryTraceContext.fromPropagationContext(
      PropagationContext propagationContext) {
    return SentryTraceContext(
      traceId: propagationContext.traceId,
      spanId: propagationContext.spanId,
      operation: 'default',
    );
  }
}
