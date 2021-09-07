import '../sentry.dart';
import 'utils.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime _startTimestamp;
  static const String _type = 'transaction';
  late final List<ISentrySpan> _spans;

  SentryTransaction(SentryTracer tracer)
      : super(
          timestamp: tracer.timestamp,
          transaction: tracer.name,
          tags: tracer.context.tags,
          extra: tracer.data,
          type: _type,
        ) {
    _startTimestamp = tracer.startTimestamp;

    final spanContext = tracer.context;
    _spans = tracer.children;

    final traceContext = SentryTraceContext(
      operation: spanContext.operation,
      traceId: spanContext.traceId,
      spanId: spanContext.spanId,
      description: spanContext.description,
      status: spanContext.status,
      parentId: spanContext.parentId,
      sampled: spanContext.sampled,
    );

    contexts.trace = traceContext;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();

    if (_spans.isNotEmpty) {
      json['spans'] = _spans.map((e) => e.toJson()).toList(growable: false);
    }
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(_startTimestamp);

    return json;
  }

  bool get finished => timestamp != null;

  bool get sampled => contexts.trace?.sampled == true;
}
