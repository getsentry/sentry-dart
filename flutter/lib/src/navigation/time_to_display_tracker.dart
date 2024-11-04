// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final TimeToInitialDisplayTracker _ttidTracker;
  final TimeToFullDisplayTracker _ttfdTracker;
  final SentryFlutterOptions options;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required this.options,
  })  : _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker(),
        _ttfdTracker = ttfdTracker ?? TimeToFullDisplayTracker();

  Future<void> track(
    ISentrySpan transaction, {
    required DateTime startTimestamp,
    DateTime? endTimestamp,
    String? origin,
  }) async {
    // TTID
    await _ttidTracker.track(
      transaction: transaction,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      origin: origin,
    );

    // TTFD
    if (options.enableTimeToFullDisplayTracing) {
      await _ttfdTracker.track(
        transaction: transaction,
        startTimestamp: startTimestamp,
      );
    }
  }

  @internal
  Future<void> reportFullyDisplayed() async {
    if (options.enableTimeToFullDisplayTracing) {
      return _ttfdTracker.reportFullyDisplayed();
    }
  }

  void clear() {
    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
