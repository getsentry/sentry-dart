import '../../../sentry_flutter.dart';
import 'url_filter_event_processor.dart';

UrlFilterEventProcessor urlFilterEventProcessor(SentryFlutterOptions _) =>
    IoUrlFilterEventProcessor();

class IoUrlFilterEventProcessor implements UrlFilterEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, Hint hint) => event;
}
