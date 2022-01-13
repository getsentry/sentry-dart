import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'sentry_tracer_finish_status.dart';

@internal
class SentryTracer extends ISentrySpan {
  final Hub _hub;
  late bool _waitForChildren;
  late String name;

  late final SentrySpan _rootSpan;
  final List<SentrySpan> _children = [];
  final Map<String, dynamic> _extra = {};
  Timer? _autoFinishAfterTimer;
  var _finishStatus = SentryTracerFinishStatus.notFinishing();

  SentryTracer(SentryTransactionContext transactionContext, this._hub,
      {bool waitForChildren = false, Duration? autoFinishAfter}) {
    _rootSpan = SentrySpan(
      this,
      transactionContext,
      _hub,
      sampled: transactionContext.sampled,
    );
    _waitForChildren = waitForChildren;
    if (autoFinishAfter != null) {
      _autoFinishAfterTimer = Timer(autoFinishAfter, () async {
        await finish(status: status ?? SpanStatus.ok());
      });
    }
    name = transactionContext.name;
  }

  @override
  Future<void> finish({SpanStatus? status}) async {
    _autoFinishAfterTimer?.cancel();
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

      final transaction = SentryTransaction(this, measurements: measurements);
      await _hub.captureTransaction(transaction);
    }
  }

  @override
  void removeData(String key) {
    if (finished) {
      return;
    }

    _extra.remove(key);
  }

  @override
  void removeTag(String key) {
    if (finished) {
      return;
    }

    _rootSpan.removeTag(key);
  }

  @override
  void setData(String key, dynamic value) {
    if (finished) {
      return;
    }

    _extra[key] = value;
  }

  @override
  void setTag(String key, String value) {
    if (finished) {
      return;
    }

    _rootSpan.setTag(key, value);
  }

  final List<SentryMeasurement> measurements = [];

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
  }) {
    if (finished) {
      return NoOpSentrySpan();
    }

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
    if (finished) {
      return NoOpSentrySpan();
    }

    final context = SentrySpanContext(
        traceId: _rootSpan.context.traceId,
        parentSpanId: parentSpanId,
        operation: operation,
        description: description);

    final child = SentrySpan(this, context, _hub, sampled: _rootSpan.sampled,
        finishedCallback: () {
      final finishStatus = _finishStatus;
      if (finishStatus.finishing) {
        finish(status: finishStatus.status);
      }
    });

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

  Map<String, dynamic> get data => Map.unmodifiable(_extra);

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
