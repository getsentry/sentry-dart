import '../../../sentry.dart';
import 'url_filter_event_processor.dart';

UrlFilterEventProcessor urlFilterEventProcessor(SentryOptions options) =>
    UrlFilterEventProcessor(options);

class IoUrlFilterEventProcessor implements UrlFilterEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, Hint hint) => event;
}
