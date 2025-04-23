import '../../sentry_flutter.dart';

class SentryDisplay {
  final Hub _hub;
  final SpanId spanId;

  SentryDisplay(this.spanId, {Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<void> reportFullyDisplayed() async {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    if (options is SentryFlutterOptions) {
      try {
        return options.timeToDisplayTracker.reportFullyDisplayed(
          spanId: spanId,
        );
      } catch (exception, stackTrace) {
        options.logger(
          SentryLevel.error,
          'Error while reporting TTFD',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
