import 'dart:async';

import '../../sentry.dart';

typedef Task<T> = Future<T> Function();

class TaskQueue<T> {
  TaskQueue(this._maxQueueSize, this._logger);

  final int _maxQueueSize;
  final SentryLogger _logger;

  int _queueCount = 0;

  Future<T> enqueue(Task<T> task, T fallbackResult) async {
    if (_queueCount >= _maxQueueSize) {
      _logger(SentryLevel.warning,
          'Task dropped due to backpressure. Avoid capturing in a tight loop.');
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
