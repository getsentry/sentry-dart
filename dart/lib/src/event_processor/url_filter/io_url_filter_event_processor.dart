import '../../../sentry.dart';
import 'url_filter_event_processor.dart';

UrlFilterEventProcessor urlFilterEventProcessor(SentryOptions _) =>
    IoUrlFilterEventProcessor();

class IoUrlFilterEventProcessor implements UrlFilterEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, Hint hint) => event;
}
