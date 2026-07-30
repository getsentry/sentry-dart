// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../navigation/time_to_display_tracker.dart';
import '../../navigation/time_to_display_tracker_v2.dart';

/// The initial-display tracking a standalone app start drives.
///
/// Each trace lifecycle has its own display tracker with a differently named
/// API. This is the shape the app-start handler needs from both, so it
/// picks an implementation once instead of switching at every call site
/// and hand-pairing each `prepare` with the matching cancel.
@internal
abstract interface class AppStartDisplayTracking {
  factory AppStartDisplayTracking.forOptions(SentryFlutterOptions options) =>
      switch (options.traceLifecycle) {
        SentryTraceLifecycle.static =>
          _StaticAppStartDisplayTracking(options.timeToDisplayTracker),
        SentryTraceLifecycle.stream =>
          _StreamingAppStartDisplayTracking(options.timeToDisplayTrackerV2),
      };

  /// Opens initial-display tracking for an app start that began at
  /// [startTimestamp].
  void prepare(DateTime startTimestamp);

  /// Reports the first frame as the initial display.
  Future<void> record(DateTime endTimestamp);

  /// Abandons whatever [prepare] opened.
  void cancel();
}

final class _StaticAppStartDisplayTracking implements AppStartDisplayTracking {
  _StaticAppStartDisplayTracking(this._tracker);

  final TimeToDisplayTracker _tracker;

  @override
  void prepare(DateTime startTimestamp) =>
      _tracker.prepareInitialDisplay(startTimestamp);

  @override
  Future<void> record(DateTime endTimestamp) =>
      _tracker.recordInitialDisplay(endTimestamp);

  @override
  void cancel() => _tracker.clear();
}

final class _StreamingAppStartDisplayTracking
    implements AppStartDisplayTracking {
  _StreamingAppStartDisplayTracking(this._tracker);

  final TimeToDisplayTrackerV2 _tracker;

  @override
  void prepare(DateTime startTimestamp) =>
      _tracker.prepareAppStart(startTimestamp: startTimestamp);

  @override
  Future<void> record(DateTime endTimestamp) async =>
      _tracker.trackAppStart(ttidEndTimestamp: endTimestamp);

  @override
  void cancel() => _tracker.cancelCurrentRoute();
}
