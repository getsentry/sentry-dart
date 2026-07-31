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
    final spanId = json.readString('span_id');
    final parentSpanId = json.readString('parent_span_id');
    final traceId = json.readString('trace_id');
    final replayId = json.readString('replay_id');
    final status = json.readString('status');
    return SentryTraceContext(
      // Required by the constructor: without it there is no usable trace
      // context, so the caller drops this child and keeps the raw JSON.
      operation: json.readString('op')!,
      spanId: spanId != null ? SpanId.fromId(spanId) : null,
      parentSpanId: parentSpanId != null ? SpanId.fromId(parentSpanId) : null,
      traceId: traceId != null ? SentryId.fromId(traceId) : null,
      replayId: replayId != null ? SentryId.fromId(replayId) : null,
      description: json.readString('description'),
      status: status != null ? SpanStatus.fromString(status) : null,
      sampled: true,
      origin: json.readString('origin'),
      data: json.readMap('data'),
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
      'parent_span_id': ?parentSpanId?.toString(),
      'replay_id': ?replayId?.toString(),
      'description': ?description,
      'status': ?status?.toString(),
      'origin': ?origin,
      'data': ?data,
    };
  }

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
  }) : traceId = traceId ?? SentryId.newId(),
       spanId = spanId ?? SpanId.newId();

  @internal
  factory SentryTraceContext.fromPropagationContext(
    PropagationContext propagationContext,
  ) {
    return SentryTraceContext(
      traceId: propagationContext.traceId,
      spanId: SpanId.newId(),
      operation: 'default',
      sampled: propagationContext.sampled,
      replayId: propagationContext.baggage?.getReplayId(),
    );
  }
}
