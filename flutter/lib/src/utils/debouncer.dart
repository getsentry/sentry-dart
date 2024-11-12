import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class Debouncer {
  final ClockProvider clockProvider;
  final int waitTimeMs;
  final bool debounceOnFirstTry;
  DateTime? _lastExecutionTime;

  Debouncer(this.clockProvider,
      {this.waitTimeMs = 2000, this.debounceOnFirstTry = false});

  bool shouldDebounce() {
    final currentTime = clockProvider();
    final lastExecutionTime = _lastExecutionTime;
    _lastExecutionTime = currentTime;

    if (lastExecutionTime == null && debounceOnFirstTry) {
      return true;
    }

    if (lastExecutionTime != null &&
        currentTime.difference(lastExecutionTime).inMilliseconds < waitTimeMs) {
      return true;
    }

    return false;
  }
}
