// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';

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
          Duration(seconds: 30),
        );
  }

  ISentrySpan? ttidSpan;
  ISentrySpan? ttfdSpan;

  Future<void> track(
    ISentrySpan transaction, {
    DateTime? endTimestamp,
    String? origin,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    // TTID
    ttidSpan = await _ttidTracker.track(
      transaction: transaction,
      endTimestamp: endTimestamp,
      origin: origin,
    );

    // TTFD
    if (options.enableTimeToFullDisplayTracing) {
      ttfdSpan = await _ttfdTracker.track(
        transaction: transaction,
        ttidEndTimestamp: ttidSpan?.endTimestamp,
      );
    }
  }

  @internal
  Future<void> reportFullyDisplayed({SpanId? spanId}) async {
    if (options.enableTimeToFullDisplayTracing) {
      return _ttfdTracker.reportFullyDisplayed(spanId: spanId);
    }
  }

  void clear() {
    _ttidTracker.clear();
    ttidSpan = null;

    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
      ttfdSpan = null;
    }
  }
}
