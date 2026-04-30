// ignore_for_file: experimental_member_use

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';

/// Represents the current route and allows to report the time to full display.
///
/// Make sure to get this before you do long running operations after which
/// you want to report the time to full display in your widget.
///
/// ```dart
/// final display = SentryFlutter.currentDisplay();
///
/// // Do long running operations...
///
/// await display.reportFullyDisplayed();
/// ```
class SentryDisplay {
  final Hub _hub;
  final SpanId spanId;

  SentryDisplay(this.spanId, {Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<void> reportFullyDisplayed() async {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    try {
      if (options.traceLifecycle == SentryTraceLifecycle.stream) {
        options.timeToDisplayTrackerV2.reportFullyDisplayed(spanId);
      } else {
        await options.timeToDisplayTracker.reportFullyDisplayed(
          spanId: spanId,
        );
      }
    } catch (exception, stackTrace) {
      if (options.automatedTestMode) {
        rethrow;
      }
      internalLogger.error(
        'Error while reporting TTFD',
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
