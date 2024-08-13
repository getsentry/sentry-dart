import '../../../sentry_flutter.dart';
import 'io_url_filter_event_processor.dart'
    if (dart.library.html) 'web_url_filter_event_processor.dart';

abstract class UrlFilterEventProcessor implements EventProcessor {
  factory UrlFilterEventProcessor(SentryFlutterOptions options) =>
      urlFilterEventProcessor(options);
}
