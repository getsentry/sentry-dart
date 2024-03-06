// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final TimeToInitialDisplayTracker _ttidTracker;
  late final TimeToFullDisplayTracker? _ttfdTracker;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required bool enableTimeToFullDisplayTracing,
  })  :
        _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker() {
    if (enableTimeToFullDisplayTracing) {
      _ttfdTracker = ttfdTracker ?? TimeToFullDisplayTracker();
    }
  }

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

  @internal
  Future<void> reportFullyDisplayed() async {
    return _ttfdTracker?.reportFullyDisplayed();
  }

  void clear() {
    _ttidTracker.clear();
  }
}
