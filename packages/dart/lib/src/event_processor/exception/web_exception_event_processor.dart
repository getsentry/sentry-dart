import '../../hint.dart';
import '../../protocol.dart';
import '../../sentry_options.dart';
import 'exception_event_processor.dart';

ExceptionEventProcessor exceptionEventProcessor(SentryOptions _) =>
    WebExcptionEventProcessor();

class WebExcptionEventProcessor implements ExceptionEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, Hint hint) => event;
}
