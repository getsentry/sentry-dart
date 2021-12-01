import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracer extends ISentrySpan {
  final Hub _hub;
  late bool _waitForChildren;
  late String name;

  late final SentrySpan _rootSpan;
  final List<SentrySpan> _children = [];
  final Map<String, String> _extra = {};
  Timer? _finishAfterTimer;
  var _finishStatus = SentryTracerFinishStatus.notFinishing();

  SentryTracer(SentryTransactionContext transactionContext, this._hub,
      {bool waitForChildren = false}) {
    _rootSpan = SentrySpan(
      this,
      transactionContext,
      _hub,
      sampled: transactionContext.sampled,
    );
    _waitForChildren = waitForChildren;
    name = transactionContext.name;
  }

  @override
  Future<void> finish({SpanStatus? status}) async {
    _finishAfterTimer?.cancel();
    _finishStatus = SentryTracerFinishStatus.finishing(status);
    if (!_rootSpan.finished &&
        (!_waitForChildren || _haveAllChildrenFinished())) {
      _rootSpan.status ??= status;
      await _rootSpan.finish();

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

      final transaction = SentryTransaction(this);
      await _hub.captureTransaction(transaction);

      finishedCallback?.call();
    }
  }

  @override
  void finishAfter(Duration duration, {SpanStatus? status}) {
    _finishAfterTimer = Timer(duration, () async {
      await finish(status: status);
    });
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
    final child = _rootSpan.startChild(
      operation,
      description: description,
    );
    child.finishedCallback = () {
      final finishStatus = _finishStatus;
      if (finishStatus.finishing) {
        finish(status: finishStatus.status);
      }
    };
    return child;
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
    );

    final child = SentrySpan(
      this,
      context,
      _hub,
      sampled: _rootSpan.sampled,
    );

    _children.add(child);

    return child;
  }

  @override
  SpanStatus? get status => _rootSpan.status;

  @override
  SentrySpanContext get context => _rootSpan.context;

  @override
  DateTime get startTimestamp => _rootSpan.startTimestamp;

  @override
  DateTime? get endTimestamp => _rootSpan.endTimestamp;

  Map<String, String> get data => Map.unmodifiable(_extra);

  @override
  bool get finished => _rootSpan.finished;

  List<SentrySpan> get children => _children;

  @override
  dynamic get throwable => _rootSpan.throwable;

  @override
  set throwable(throwable) => _rootSpan.throwable = throwable;

  @override
  set status(SpanStatus? status) => _rootSpan.status = status;

  Map<String, String> get tags => _rootSpan.tags;

  @override
  bool? get sampled => _rootSpan.sampled;

  @override
  SentryTraceHeader toSentryTrace() => _rootSpan.toSentryTrace();

  bool _haveAllChildrenFinished() {
    for (final child in children) {
      if (!child.finished) {
        return false;
      }
    }
    return true;
  }
}

@internal
class SentryTracerFinishStatus {
  final bool finishing;
  final SpanStatus? status;

  SentryTracerFinishStatus.finishing(SpanStatus? status)
      : finishing = true,
        status = status;

  SentryTracerFinishStatus.notFinishing()
      : finishing = false,
        status = null;
}
