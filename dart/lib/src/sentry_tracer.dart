import 'package:meta/meta.dart';

import '../sentry.dart';
import 'tracing.dart';

@internal
class SentryTracer extends ISentrySpan {
  final Hub _hub;
  late final String _name;

  // missing waitForChildren

  late final ISentrySpan _rootSpan;
  final List<ISentrySpan> _children = [];
  final Map<String, String> _extra = {};

  SentryTracer(SentryTransactionContext transactionContext, this._hub) {
    _rootSpan = SentrySpan(this, transactionContext);
    _name = transactionContext.name;
  }

  @override
  Future<void> finish({SpanStatus? status}) async {
    await _rootSpan.finish(status: status);

    // finish unfinished spans otherwise transaction gets dropped
    for (final span in _children) {
      if (!span.finished) {
        await span.finish(status: SpanStatus.deadlineExceeded());
      }
    }

    // remove from scope
    _hub.configureScope((scope) {
      if (scope.span == this) {
        scope.span = null;
      }
    });

    final transaction = _toTransaction();
    await _hub.captureTransaction(transaction);
  }

  @override
  void removeData(String key) {
    _extra.remove(key);
  }

  @override
  void removeTag(String key) {
    _rootSpan.removeTag(key);
  }

  @override
  void setData(String key, value) {
    _extra[key] = value;
  }

  @override
  void setTag(String key, String value) {
    _rootSpan.setTag(key, value);
  }

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
  }) {
    return _rootSpan.startChild(
      operation,
      description: description,
    );
  }

  ISentrySpan startChildWithParentSpanId(
    SpanId parentSpanId,
    String operation, {
    String? description,
  }) {
    final context = SentrySpanContext(
      traceId: _rootSpan.context.traceId,
      parentSpanId: parentSpanId,
      operation: operation,
      description: description,
      sampled: _rootSpan.context.sampled,
    );

    final child = SentrySpan(this, context);

    _children.add(child);

    return child;
  }

  SentryTransaction _toTransaction() {
    return SentryTransaction(this);
  }

  @override
  SpanStatus? get status => _rootSpan.status;

  @override
  SentrySpanContext get context => _rootSpan.context;

  @override
  DateTime get startTimestamp => _rootSpan.startTimestamp;

  @override
  DateTime? get endTimestamp => _rootSpan.endTimestamp;

  String get name => _name;

  @override
  Map<String, String> get data => Map.unmodifiable(_extra);

  @override
  bool get finished => _rootSpan.finished;

  List<ISentrySpan> get children => _children;
}
