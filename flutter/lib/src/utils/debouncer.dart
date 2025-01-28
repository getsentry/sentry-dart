import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class Debouncer {
  final ClockProvider clockProvider;
  final Duration waitTime;
  DateTime? _lastExecutionTime;

  Debouncer(this.clockProvider,
      {this.waitTime = const Duration(milliseconds: 2000)});

  bool shouldDebounce() {
    final currentTime = clockProvider();
    final lastExecutionTime = _lastExecutionTime;
    _lastExecutionTime = currentTime;

    if (lastExecutionTime != null &&
        currentTime.difference(lastExecutionTime) < waitTime) {
      return true;
    }

    return false;
  }
}
