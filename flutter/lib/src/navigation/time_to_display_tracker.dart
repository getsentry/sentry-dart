// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  late final TimeToInitialDisplayTracker _ttidTracker;
  late final TimeToFullDisplayTracker _ttfdTracker;

  final SentryFlutterOptions options;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required this.options,
  }) {
    _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker();
    _ttfdTracker = ttfdTracker ??
        TimeToFullDisplayTracker(
          options,
          () => _ttidTracker.endTimestamp,
        );
  }

  @internal
  DateTime? get ttidEndTimestamp => _ttidTracker.endTimestamp;

  Future<void> track(
    ISentrySpan transaction, {
    required String routeName,
    DateTime? endTimestamp,
    String? origin,
  }) async {
    // TTID
    await _ttidTracker.track(
      transaction: transaction,
      endTimestamp: endTimestamp,
      origin: origin,
    );

    // TTFD
    if (options.enableTimeToFullDisplayTracing) {
      await _ttfdTracker.track(
        transaction: transaction,
        routeName: routeName,
      );
    }
  }

  @internal
  Future<void> reportFullyDisplayed({String? routeName}) async {
    if (options.enableTimeToFullDisplayTracing) {
      return _ttfdTracker.reportFullyDisplayed(routeName: routeName);
    }
  }

  void clear() {
    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
