// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final TimeToInitialDisplayTracker _ttidTracker;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
  }) : _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker();

  Future<void> trackAppStartTTD(ISentrySpan transaction,
      {required DateTime startTimestamp,
      required DateTime endTimestamp}) async {
    // We start and immediately finish the spans since we cannot mutate the history of spans.
    await _ttidTracker.trackAppStart(transaction,
        startTimestamp: startTimestamp, endTimestamp: endTimestamp);
  }

  Future<void> trackRegularRouteTTD(ISentrySpan transaction,
      {required DateTime startTimestamp}) async {
    await _ttidTracker.trackRegularRoute(transaction, startTimestamp);
  }

  void clear() {
    _ttidTracker.clear();
  }
}
