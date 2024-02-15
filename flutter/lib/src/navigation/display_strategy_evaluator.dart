import 'dart:async';

import 'package:meta/meta.dart';

@internal
class DisplayStrategyEvaluator {
  static final DisplayStrategyEvaluator _instance =
      DisplayStrategyEvaluator._internal();

  factory DisplayStrategyEvaluator() {
    return _instance;
  }

  DisplayStrategyEvaluator._internal();

  final Map<String, bool> _manualReportReceived = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Completer<TimeToDisplayStrategy>> _completers = {};

  Future<TimeToDisplayStrategy> decideStrategy(String routeName) {
    // Ensure initialization of a completer for the given route name.
    if (!_completers.containsKey(routeName) ||
        _completers[routeName]!.isCompleted) {
      _completers[routeName] = Completer<TimeToDisplayStrategy>();
    }
    var completer = _completers[routeName]!;

    // Start or reset the timer only if a manual report has not been received.
    if (!_manualReportReceived.containsKey(routeName) ||
        !_manualReportReceived[routeName]!) {
      _timers[routeName]?.cancel(); // Cancel any existing timer.
      _timers[routeName] = Timer(Duration(seconds: 1), () {
        if (!_manualReportReceived.containsKey(routeName) ||
            !_manualReportReceived[routeName]!) {
          if (!completer.isCompleted) {
            completer.complete(TimeToDisplayStrategy.approximation);
          }
        }
      });
    }

    return completer.future;
  }

  bool reportManual(String routeName) {
    var wasReportedAlready = _manualReportReceived[routeName] ?? false;
    _manualReportReceived[routeName] = true;

    // Complete the strategy decision as manual if within the timeout period.
    if (_completers[routeName]?.isCompleted == false) {
      _completers[routeName]?.complete(TimeToDisplayStrategy.manual);
    }

    // Cancel the timer as it's no longer necessary.
    _timers[routeName]?.cancel();
    return wasReportedAlready;
  }
}

enum TimeToDisplayStrategy {
  manual,
  approximation,
}
