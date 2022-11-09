import '../../protocol.dart';
import 'exception_event_processor.dart';

ExceptionEventProcessor exceptionEventProcessor() =>
    WebExcptionEventProcessor();

class WebExcptionEventProcessor implements ExceptionEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, {dynamic hint}) => event;
}
