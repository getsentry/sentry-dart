import '../../event_processor.dart';
import '../../sentry_options.dart';
import 'io_enricher_event_processor.dart'
    if (dart.library.html) 'html_enricher_event_processor.dart'
    if (dart.library.js_interop) 'web_enricher_event_processor.dart';

abstract class EnricherEventProcessor implements EventProcessor {
  factory EnricherEventProcessor(SentryOptions options) =>
      enricherEventProcessor(options);
}
