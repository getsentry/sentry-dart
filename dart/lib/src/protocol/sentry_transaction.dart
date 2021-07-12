import 'dart:async';

import '../hub.dart';
import '../protocol.dart';
import '../utils.dart';
import 'span_interface.dart';
import 'sentry_span.dart';
import 'span_id.dart';
import 'sentry_id.dart';
import 'span_status.dart';

class SentryTransaction extends SpanInterface with SpanMixin {
  static const type = 'transaction';
  SentryTransaction({
    required SentryTransactionContext context,
    required this.hub,
    SentryId? eventId,
    DateTime? start,
  })  : eventId = eventId ?? SentryId.newId(),
        start = start ?? getUtcDateTime(),
        transactionContext = context {
    data = SentryEvent(eventId: eventId);
  }

  final SentryId eventId;
  final Hub hub;
  SentrySpan? get root => _children.isEmpty ? null : _children.first;
  final List<SentrySpan> _children = [];
  late SentryEvent data;

  @override
  final DateTime start;

  @override
  DateTime? end;

  @override
  SentrySpanContext get context => transactionContext;
  SentryTransactionContext transactionContext;

  Map<String, dynamic> toJson() {
    // https://develop.sentry.dev/sdk/event-payloads/transaction/
    // Transaction is intended to be a subclass of SentryEvent,
    // but immutability makes this cumbersome to model it like this.
    // So Transaction has a SentryEvent.
    // We need to modify the json accordingly, namely:
    // - TransactionContext goes to SentryEvent.contexts.trace
    // - Transaction.spans -> json['spans']
    // - Transaction.eventId override SentryEvent.eventId
    // - Transaction.endTimestamp override SentryEvent.timestamp
    data = data.copyWith(contexts: data.contexts.copyWith(trace: context));
    final json = data.toJson();
    json['type'] = type;
    json['spans'] = _children.map((e) => e.toJson()).toList(growable: false);
    json['start_timestamp'] = formatDateAsIso8601WithMillisPrecision(start);
    if (end != null) {
      json['timestamp'] = formatDateAsIso8601WithMillisPrecision(end!);
    }
    json['transaction'] = (context as SentryTransactionContext).name;

    return json;
  }

  SentrySpan startChild({
    SpanId? parentId,
    String? operation,
    String? description,
    DateTime? start,
  }) {
    final span = SentrySpan(
      transaction: this,
      hub: hub,
      start: start ?? getUtcDateTime(),
      context: SentrySpanContext(
        traceId: context.traceId,
        parentSpanId: parentId ?? context.spanId,
        operation: operation ?? context.operation,
        description: description,
      ),
    );

    _children.add(span);
    return span;
  }

  @override
  FutureOr<void> finish({
    SpanStatus? status,
    DateTime? end,
  }) async {
    this.end = end ?? getUtcDateTime();
    transactionContext = transactionContext.copyTransactionContextWith(
      status: status,
    );
    await hub.captureTransaction(this);
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

  factory SentryTransactionContext.fromJson(Map<String, dynamic> json) {
    return SentryTransactionContext(
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
      name: json['name'] as String,
    );
  }

  final String name;

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()..addAll({'name': name});
  }

  SentryTransactionContext copyTransactionContextWith({SpanStatus? status}) {
    return SentryTransactionContext(
      operation: operation,
      name: name,
      status: status ?? this.status,
      isSampled: isSampled,
      parentSpanId: parentSpanId,
      description: description,
      spanId: spanId,
      tags: tags,
      traceId: traceId,
    );
  }
}
