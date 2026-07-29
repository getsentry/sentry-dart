import 'dart:async';

import 'package:meta/meta.dart';

import '../client_reports/client_report_recorder.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';
import '../utils/internal_logger.dart';

typedef Task<T> = Future<T> Function();

@internal
abstract class TaskQueue<T> {
  Future<T> enqueue(Task<T> task, T fallbackResult, DataCategory category);
}

@internal
class DefaultTaskQueue<T> implements TaskQueue<T> {
  DefaultTaskQueue(this._maxQueueSize, this._recorder);

  final int _maxQueueSize;
  final ClientReportRecorder _recorder;

  int _queueCount = 0;

  @override
  Future<T> enqueue(
    Task<T> task,
    T fallbackResult,
    DataCategory category,
  ) async {
    if (_queueCount >= _maxQueueSize) {
      _recorder.recordLostEvent(DiscardReason.queueOverflow, category);
      internalLogger.warning(
        'Task dropped due to reaching max of $_maxQueueSize parallel tasks.',
      );
      return fallbackResult;
    } else {
      _queueCount++;
      try {
        return await task();
      } finally {
        _queueCount--;
      }
    }
  }
}

@internal
class NoOpTaskQueue<T> implements TaskQueue<T> {
  @override
  Future<T> enqueue(
    Task<T> task,
    T fallbackResult,
    DataCategory category,
  ) {
    return task();
  }
}
