import '../event_processor.dart';
import '../sentry_options.dart';
import 'io_enricher_event_processor.dart'
    if (dart.library.html) 'web_enricher_event_processor.dart';

EventProcessor getEnricherEventProcessor(SentryOptions options) {
  return enricherEventProcessor(options);
}
