// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

class FakeTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  final List<String> trackRouteChangeCalls = [];
  final List<String?> setAppStartRouteNameCalls = [];
  int cancelCurrentRouteCalls = 0;
  bool _isAppStartRoutePending = true;

  @override
  SentrySpanV2 trackRoute(String routeName) {
    trackRouteChangeCalls.add(routeName);
    return NoOpSentrySpanV2();
  }

  @override
  bool get isAppStartRoutePending => _isAppStartRoutePending;

  @override
  void setAppStartRouteName(String? routeName) {
    setAppStartRouteNameCalls.add(routeName);
    _isAppStartRoutePending = false;
  }

  @override
  void cancelCurrentRoute() {
    cancelCurrentRouteCalls++;
  }
}
