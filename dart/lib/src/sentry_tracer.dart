import '../sentry.dart';
import 'tracing.dart';

class SentryTracer implements ISentrySpan {
  final Hub _hub;
  late String _name;

  // missing waitForChildren

  late ISentrySpan _rootSpan;
  final List<ISentrySpan> _children = [];

  SentryTracer(SentryTransactionContext transactionContext, this._hub) {
    _rootSpan = SentrySpan(this, transactionContext);
    _name = transactionContext.name;
  }

  @override
  void finish({SpanStatus? status}) {
    _rootSpan.finish(status: status);
    captureTransaction();
  }

  @override
  void removeData(String key) {
    _rootSpan.removeData(key);
  }

  @override
  void removeTag(String key) {
    _rootSpan.removeTag(key);
  }

  @override
  void setData(String key, value) {
    _rootSpan.setData(key, value);
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

  ISentrySpan startChildWithParentId(
    SpanId parentId,
    String operation, {
    String? description,
  }) {
    final context = SentrySpanContext(
      traceId: _rootSpan.context.traceId,
      parentId: parentId,
      operation: operation,
      description: description,
      sampled: _rootSpan.context.sampled,
    );

    final child = SentrySpan(this, context);

    _children.add(child);

    return child;
  }

  // missing hasUnfinishedChildren & isWaitingForChildren feature

  void captureTransaction() {
    _hub.configureScope((scope) {
      if (scope.span == this) {
        scope.span = null;
      }
    });

    final transaction = _toTransaction();
    _hub.captureTransaction(transaction);
  }

  SentryTransaction _toTransaction() {
    // filter unfinished spans _children
    return SentryTransaction(this, _children, _name);
  }

  @override
  SpanStatus? get status => _rootSpan.status;

  @override
  SentrySpanContext get context => _rootSpan.context;

  @override
  DateTime get startTimestamp => _rootSpan.startTimestamp;

  @override
  DateTime? get timestamp => _rootSpan.timestamp;
}
