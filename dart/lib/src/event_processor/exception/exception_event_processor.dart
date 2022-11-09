import '../../event_processor.dart';
import 'io_exception_event_processor.dart'
    if (dart.library.html) 'web_exception_event_processor.dart';

abstract class ExceptionEventProcessor implements EventProcessor {
  factory ExceptionEventProcessor() => exceptionEventProcessor();
}
