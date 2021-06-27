import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';

/// Records the time which a frame takes to draw, if it's above
/// a certain threshold, i.e. [FrameTimingIntegration.badFrameThreshold].
///
/// Should not be added in debug mode because the performance of the debug mode
/// is not indicativ of the performance in release mode.
///
/// Remarks:
/// See [SchedulerBinding.addTimingsCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html)
/// to learn more about the performance impact of using this.
///
/// Adding a `timingsCallback` has a real significant performance impact as
/// noted above. Thus this integration should only be added if it's enabled.
/// The enabled check should not happen inside the `timingsCallback`.
class FrameTimingIntegration extends Integration<SentryFlutterOptions> {
  FrameTimingIntegration({
    required this.reporter,
    this.badFrameThreshold = const Duration(milliseconds: 16),
  });

  final Duration badFrameThreshold;
  final FrameTimingReporter reporter;

  late Hub _hub;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `WidgetsFlutterBindingIntegration` already calls it.
    // If the instance is not created, we skip it to keep going.
    final instance = WidgetsBinding.instance;
    if (instance != null) {
      _hub = hub;
      instance.addTimingsCallback(_timingsCallback);
      options.sdk.addIntegration('FrameTimingsIntegration');
    } else {
      options.logger(
        SentryLevel.error,
        'FrameTimingsIntegration failed to be installed',
      );
    }
  }

  void _timingsCallback(List<FrameTiming> timings) {
    var count = 0;
    var worstFrameDuration = Duration.zero;
    for (final timing in timings) {
      if (timing.totalSpan > badFrameThreshold) {
        count = count + 1;
        if (timing.totalSpan > worstFrameDuration) {
          worstFrameDuration = timing.totalSpan;
        }
      }
    }
    if (count > 0) {
      final totalDuration =
          timings.map((e) => e.totalSpan).reduce((a, b) => a + b);

      final message = _message(count, worstFrameDuration, totalDuration);

      if (reporter == FrameTimingReporter.breadcrumb) {
        _reportAsBreadcrumb(message);
      } else {
        // This callback does not allow async, so we captureMessage as
        // a fire and forget action.
        _reportAsEvent(message);
      }
    }
  }

  Future<void> _reportAsEvent(String message) {
    return _hub.captureMessage(
      message,
      level: SentryLevel.warning,
    );
  }

  void _reportAsBreadcrumb(String message) {
    _hub.addBreadcrumb(Breadcrumb(
      type: 'info',
      category: 'ui',
      message: message,
      level: SentryLevel.warning,
    ));
  }

  String _message(
    int badFrameCount,
    Duration worstFrameDuration,
    Duration totalDuration,
  ) {
    return '$badFrameCount frames exceeded ${_formatMS(badFrameThreshold)} '
        'in the last ${_formatMS(totalDuration)}. '
        'The worst frame time in this time span was '
        '${_formatMS(worstFrameDuration)}';
  }

  @override
  FutureOr<void> close() {
    WidgetsBinding.instance?.removeTimingsCallback(_timingsCallback);
  }

  /// Format milliseconds with more precision than absolut milliseconds
  String _formatMS(Duration duration) => '${duration.inMicroseconds * 0.001}ms';
}

enum FrameTimingReporter {
  breadcrumb,
  event,
}
