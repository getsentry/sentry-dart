// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final TimeToInitialDisplayTracker _ttidTracker;
  final TimeToFullDisplayTracker? _ttfdTracker;
  final bool enableTimeToFullDisplayTracing;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required this.enableTimeToFullDisplayTracing,
  })  : _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker(),
        _ttfdTracker = enableTimeToFullDisplayTracing
            ? ttfdTracker ?? TimeToFullDisplayTracker()
            : null;

  Future<void> trackRegularRouteTTD(ISentrySpan transaction,
      {required DateTime startTimestamp}) async {
    await _ttidTracker.trackRegularRoute(transaction, startTimestamp);
    await _trackTTFDIfEnabled(transaction, startTimestamp);
  }

  Future<void> _trackTTFDIfEnabled(
      ISentrySpan transaction, DateTime startTimestamp) async {
    if (enableTimeToFullDisplayTracing) {
      await _ttfdTracker?.track(transaction, startTimestamp);
    }
  }

  @internal
  Future<void> reportFullyDisplayed() async {
    return _ttfdTracker?.reportFullyDisplayed();
  }

  void clear() {
    _ttidTracker.clear();
    _ttfdTracker?.clear();
  }
}
