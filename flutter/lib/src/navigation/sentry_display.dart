import '../../sentry_flutter.dart';

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
      return options.timeToDisplayTracker.reportFullyDisplayed(
        spanId: spanId,
      );
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
