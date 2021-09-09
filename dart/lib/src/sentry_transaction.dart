import '../sentry.dart';
import 'sentry_tracer.dart';
import 'utils.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  static const String _type = 'transaction';
  late final List<ISentrySpan> spans;

  SentryTransaction(SentryTracer tracer)
      : super(
          timestamp: tracer.endTimestamp,
          transaction: tracer.name,
          tags: tracer.context.tags,
          extra: tracer.data,
          type: _type,
        ) {
    startTimestamp = tracer.startTimestamp;

    final spanContext = tracer.context;
    spans = tracer.children;

    final traceContext = SentryTraceContext(
      operation: spanContext.operation,
      traceId: spanContext.traceId,
      spanId: spanContext.spanId,
      description: spanContext.description,
      status: spanContext.status,
      parentSpanId: spanContext.parentSpanId,
      sampled: spanContext.sampled,
    );

    contexts.trace = traceContext;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();

    if (spans.isNotEmpty) {
      json['spans'] = spans.map((e) => e.toJson()).toList(growable: false);
    }
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(startTimestamp);

    return json;
  }

  bool get finished => timestamp != null;

  bool get sampled => contexts.trace?.sampled == true;

  // @override
  // SentryEvent copyWith({
  //   SentryId? eventId,
  //   DateTime? timestamp,
  //   String? platform,
  //   String? logger,
  //   String? serverName,
  //   String? release,
  //   String? dist,
  //   String? environment,
  //   Map<String, String>? modules,
  //   SentryMessage? message,
  //   String? transaction,
  //   dynamic throwable,
  //   SentryLevel? level,
  //   String? culprit,
  //   Map<String, String>? tags,
  //   Map<String, dynamic>? extra,
  //   List<String>? fingerprint,
  //   SentryUser? user,
  //   Contexts? contexts,
  //   List<Breadcrumb>? breadcrumbs,
  //   SdkVersion? sdk,
  //   SentryRequest? request,
  //   DebugMeta? debugMeta,
  //   List<SentryException>? exceptions,
  //   List<SentryThread>? threads,
  //   String? type,
  // }) {
  //   final transaction = super.copyWith();
  //   return super.copyWith();
  // }
}
