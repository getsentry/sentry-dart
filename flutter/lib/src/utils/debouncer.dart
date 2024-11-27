import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class Debouncer {
  final ClockProvider clockProvider;
  final int waitTimeMs;
  DateTime? _lastExecutionTime;

  Debouncer(this.clockProvider, {this.waitTimeMs = 2000});

  bool shouldDebounce() {
    final currentTime = clockProvider();
    final lastExecutionTime = _lastExecutionTime;
    _lastExecutionTime = currentTime;

    if (lastExecutionTime != null &&
        currentTime.difference(lastExecutionTime).inMilliseconds < waitTimeMs) {
      return true;
    }

    return false;
  }
}
