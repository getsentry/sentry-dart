import '../hub.dart';
import 'span_interface.dart';
import 'sentry_span.dart';
import 'span_id.dart';
import 'sentry_id.dart';
import 'span_status.dart';

class SentryTransaction implements SpanInterface {
  SentryTransaction({
    required SentrySpanContext context,
    required this.eventId,
    required this.hub,
  }) {
    root = SentrySpan(transaction: this, hub: hub, context: context);
  }

  final SentryId eventId;
  final Hub hub;
  late SentrySpan? root;
  final List<SentrySpan> _children = [];

  Map<String, dynamic> toJson() {
    return {};
  }

  SentrySpan startChild({
    required SpanId parentId,
    required String operation,
    required String? description,
    DateTime? start,
  }) {
    final span = SentrySpan(
      transaction: this,
      hub: hub,
      start: start,
      context: SentrySpanContext(
        traceId: root?.context.traceId,
        parentSpanId: parentId,
        operation: operation,
        description: description,
      ),
    );

    _children.add(span);
    return span;
  }
}

class SentryTransactionContext extends SentrySpanContext {
  SentryTransactionContext({
    required String operation,
    SentryId? traceId,
    SpanId? spanId,
    String? description,
    SpanStatus? status,
    Map<String, String>? tags,
    SpanId? parentSpanId,
    bool? isSampled,
    required this.name,
    required this.parentSampled,
  }) : super(
          operation: operation,
          traceId: traceId,
          spanId: spanId,
          description: description,
          status: status,
          tags: tags,
          parentSpanId: parentSpanId,
          isSampled: isSampled,
        );

  final String name;
  final bool parentSampled;
}
