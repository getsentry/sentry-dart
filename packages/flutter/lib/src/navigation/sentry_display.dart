import '../../sentry_flutter.dart';
import '../display/display_handles.dart';

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
  final SpanId? spanId;
  final DisplayHandle? _handle;

  SentryDisplay(this.spanId, {Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _handle = null;

  SentryDisplay.withHandle(this._handle, {Hub? hub})
      : _hub = hub ?? HubAdapter(),
        spanId = null;

  Future<void> reportFullyDisplayed() async {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    try {
      if (options.experimentalUseDisplayTimingV2 && _handle != null) {
        // Use the public Hub clock via options; allowed internally
        // ignore: invalid_use_of_internal_member
        final now = options.clock();
        _handle.reportFullyDisplayed(now);
        return;
      }
      final id = spanId;
      if (id != null) {
        return options.timeToDisplayTracker.reportFullyDisplayed(
          spanId: id,
        );
      }
    } catch (exception, stackTrace) {
      if (options.automatedTestMode) {
        rethrow;
      }
      options.log(
        SentryLevel.error,
        'Error while reporting TTFD',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
