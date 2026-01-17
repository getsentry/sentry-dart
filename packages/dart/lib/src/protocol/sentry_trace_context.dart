import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../propagation_context.dart';
import '../protocol.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

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
    final op = json.getValueOrNull<String>('op');
    final spanId = json.getValueOrNull<String>('span_id');
    final parentSpanId = json.getValueOrNull<String>('parent_span_id');
    final traceId = json.getValueOrNull<String>('trace_id');
    final replayId = json.getValueOrNull<String>('replay_id');
    final status = json.getValueOrNull<String>('status');
    final dataValue = json.getValueOrNull<Map<String, dynamic>>('data');
    return SentryTraceContext(
      operation: op!,
      spanId: SpanId.fromId(spanId!),
      parentSpanId: parentSpanId == null ? null : SpanId.fromId(parentSpanId),
      traceId: SentryId.fromId(traceId!),
      replayId: replayId == null ? null : SentryId.fromId(replayId),
      description: json.getValueOrNull('description'),
      status: status == null ? null : SpanStatus.fromString(status),
      sampled: true,
      origin: json.getValueOrNull('origin'),
      data: dataValue == null ? null : Map<String, dynamic>.from(dataValue),
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
