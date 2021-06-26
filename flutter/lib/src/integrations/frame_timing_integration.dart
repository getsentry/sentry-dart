import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';

class FrameTimingIntegration extends Integration<SentryFlutterOptions> {
  late Hub _hub;

  static const maxTimeForFrames = Duration(milliseconds: 16);

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
      if (timing.totalSpan > maxTimeForFrames) {
        count = count + 1;
        if (timing.totalSpan > worstFrameDuration) {
          worstFrameDuration = timing.totalSpan;
        }
      }
    }
    if (count > 0) {
      final totalDuration =
          timings.map((e) => e.totalSpan).reduce((a, b) => a + b);

      final message =
          '$count frames exceeded ${maxTimeForFrames.inMilliseconds} in the '
          'last ${_formatMS(totalDuration)}ms. '
          'The worst frame time was ${_formatMS(worstFrameDuration)}';

      _hub.addBreadcrumb(Breadcrumb(
        message: message,
        level: SentryLevel.warning,
      ));
    }
  }

  @override
  FutureOr<void> close() {
    WidgetsBinding.instance?.removeTimingsCallback(_timingsCallback);
  }

  /// Format milliseconds with more precision than absolut milliseconds
  String _formatMS(Duration duration) => '${duration.inMicroseconds * 0.001}ms';
}
