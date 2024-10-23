import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';

typedef Task<T> = Future<T> Function();

@internal
abstract class TaskQueue<T> {
  Future<T> enqueue(Task<T> task, T fallbackResult, String warning);
}

@internal
class DefaultTaskQueue<T> implements TaskQueue<T> {
  DefaultTaskQueue(this._maxQueueSize, this._logger);

  final int _maxQueueSize;
  final SentryLogger _logger;

  int _queueCount = 0;

  @override
  Future<T> enqueue(Task<T> task, T fallbackResult, String taskName) async {
    if (_queueCount >= _maxQueueSize) {
      _logger(SentryLevel.warning,
          '$taskName dropped due to backpressure. Avoid capturing in a tight loop.');
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
  Future<T> enqueue(Task<T> task, T fallbackResult, String warning) {
    return task();
  }
}
