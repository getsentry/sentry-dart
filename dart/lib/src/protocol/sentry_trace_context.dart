import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../propagation_context.dart';
import '../protocol.dart';
import 'access_aware_map.dart';

class SentryTraceContext {
  static const String type = 'trace';

  /// Determines which trace the Span belongs to
  final SentryId traceId;

  /// Span id
  final SpanId spanId;

  /// Id of a parent span
  SpanId? parentSpanId;

  /// Replay associated with this trace.
  SentryId? replayId;

  /// Whether the span is sampled or not
  bool? sampled;

  /// Short code identifying the type of operation the span is measuring
  String operation;

  /// Longer description of the span's operation, which uniquely identifies the span but is
  /// consistent across instances of the span.
  String? description;

  /// The Span status
  SpanStatus? status;

  /// The origin of the span indicates what created the span.
  ///
  /// @note Gets set by the SDK. It is not expected to be set manually by users.
  ///
  /// @see <https://develop.sentry.dev/sdk/performance/trace-origin>
  String? origin;

  Map<String, dynamic>? data;

  @internal
  final Map<String, dynamic>? unknown;

  factory SentryTraceContext.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryTraceContext(
      operation: json['op'] as String,
      spanId: SpanId.fromId(json['span_id'] as String),
      parentSpanId: json['parent_span_id'] == null
          ? null
          : SpanId.fromId(json['parent_span_id'] as String),
      traceId: SentryId.fromId(json['trace_id'] as String),
      replayId: json['replay_id'] == null
          ? null
          : SentryId.fromId(json['replay_id'] as String),
      description: json['description'] as String?,
      status: json['status'] == null
          ? null
          : SpanStatus.fromString(json['status'] as String),
      sampled: true,
      origin: json['origin'] == null ? null : json['origin'] as String?,
      data: json['data'] == null ? null : json['data'] as Map<String, dynamic>,
      unknown: json.notAccessed(),
    );
  }

  /// Item encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId!.toString(),
      if (replayId != null) 'replay_id': replayId!.toString(),
      if (description != null) 'description': description,
      if (status != null) 'status': status!.toString(),
      if (origin != null) 'origin': origin,
      if (data != null) 'data': data,
    };
  }

  @Deprecated('Will be removed in a future version.')
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
        replayId: replayId,
        data: data,
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
    this.replayId,
    this.data,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();

  @internal
  factory SentryTraceContext.fromPropagationContext(
      PropagationContext propagationContext) {
    return SentryTraceContext(
      traceId: propagationContext.traceId,
      spanId: SpanId.newId(),
      operation: 'default',
      sampled: propagationContext.sampled,
      replayId: propagationContext.baggage?.getReplayId(),
    );
  }
}
