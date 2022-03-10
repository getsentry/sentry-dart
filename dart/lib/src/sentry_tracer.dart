import 'dart:async';

import 'package:meta/meta.dart';
import 'utils.dart';

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
  late final bool _trimEnd;

  /// If [waitForChildren] is true, this transaction will not finish until all
  /// its children are finished.
  ///
  /// When [autoFinishAfter] is provided, started transactions will
  /// automatically be finished after this duration.
  ///
  /// If [trimEnd] is true, sets the end timestamp of the transaction to the
  /// highest timestamp of child spans, trimming the duration of the
  /// transaction. This is useful to discard extra time in the transaction that
  /// is not accounted for in child spans, like what happens in the
  /// [SentryNavigatorObserver] idle transactions, where we finish the
  /// transaction after a given "idle time" and we don't want this "idle time"
  /// to be part of the transaction.
  SentryTracer(SentryTransactionContext transactionContext, this._hub,
      {DateTime? startTimestamp,
      bool waitForChildren = false,
      Duration? autoFinishAfter,
      bool trimEnd = false}) {
    _rootSpan = SentrySpan(
      this,
      transactionContext,
      _hub,
      sampled: transactionContext.sampled,
      startTimestamp: startTimestamp,
    );
    _waitForChildren = waitForChildren;
    if (autoFinishAfter != null) {
      _autoFinishAfterTimer = Timer(autoFinishAfter, () async {
        await finish(status: status ?? SpanStatus.ok());
      });
    }
    name = transactionContext.name;
    _trimEnd = trimEnd;
  }

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {
    final commonEndTimestamp = endTimestamp ?? getUtcDateTime();
    _autoFinishAfterTimer?.cancel();
    _finishStatus = SentryTracerFinishStatus.finishing(status);
    if (!_rootSpan.finished &&
        (!_waitForChildren || _haveAllChildrenFinished())) {
      _rootSpan.status ??= status;

      // remove span where its endTimestamp is before startTimestamp
      _children.removeWhere(
          (span) => !_hasSpanSuitableTimestamps(span, commonEndTimestamp));

      // finish unfinished spans otherwise transaction gets dropped
      final spansToBeFinished = _children.where((span) => !span.finished);
      await Future.forEach(
          spansToBeFinished,
          (SentrySpan span) async => await span.finish(
              status: SpanStatus.deadlineExceeded(),
              endTimestamp: commonEndTimestamp));

      var _rootEndTimestamp = commonEndTimestamp;
      if (_trimEnd && children.isNotEmpty) {
        final childEndTimestamps = children
            .where((child) => child.endTimestamp != null)
            .map((child) => child.endTimestamp!);

        if (childEndTimestamps.isNotEmpty) {
          final oldestChildEndTimestamp =
              childEndTimestamps.reduce((a, b) => a.isAfter(b) ? a : b);
          if (_rootEndTimestamp.isAfter(oldestChildEndTimestamp)) {
            _rootEndTimestamp = oldestChildEndTimestamp;
          }
        }
      }

      await _rootSpan.finish(endTimestamp: _rootEndTimestamp);

      // remove from scope
      _hub.configureScope((scope) {
        if (scope.span == this) {
          scope.span = null;
        }
      });

      final transaction = SentryTransaction(this);
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

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    if (finished) {
      return NoOpSentrySpan();
    }

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.logger(
        SentryLevel.warning,
        'Span operation: $operation, description: $description dropped due to limit reached. Returning NoOpSpan.',
      );
      return NoOpSentrySpan();
    }

    return _rootSpan.startChild(
      operation,
      description: description,
      startTimestamp: startTimestamp,
    );
  }

  ISentrySpan startChildWithParentSpanId(
    SpanId parentSpanId,
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    if (finished) {
      return NoOpSentrySpan();
    }

    if (children.length >= _hub.options.maxSpans) {
      _hub.options.logger(
        SentryLevel.warning,
        'Span operation: $operation, description: $description dropped due to limit reached. Returning NoOpSpan.',
      );
      return NoOpSentrySpan();
    }

    final context = SentrySpanContext(
        traceId: _rootSpan.context.traceId,
        parentSpanId: parentSpanId,
        operation: operation,
        description: description);

    final child = SentrySpan(this, context, _hub,
        sampled: _rootSpan.sampled, startTimestamp: startTimestamp,
        finishedCallback: ({DateTime? endTimestamp}) {
      final finishStatus = _finishStatus;
      if (finishStatus.finishing) {
        finish(status: finishStatus.status, endTimestamp: endTimestamp);
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

  bool _hasSpanSuitableTimestamps(
          SentrySpan span, DateTime endTimestampCandidate) =>
      !span.startTimestamp
          .isAfter((span.endTimestamp ?? endTimestampCandidate));
}
