// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

class FakeTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  final List<String> trackRouteCalls = [];
  int cancelCurrentRouteCalls = 0;

  @override
  SentrySpanV2 trackRoute(
    String routeName, {
    DateTime? startTimestamp,
    DateTime? ttidEndTimestamp,
  }) {
    trackRouteCalls.add(routeName);
    return NoOpSentrySpanV2();
  }

  @override
  void cancelCurrentRoute() {
    cancelCurrentRouteCalls++;
  }
}
