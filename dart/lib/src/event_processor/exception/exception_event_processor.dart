import '../../event_processor.dart';
import '../../sentry_options.dart';
import 'io_exception_event_processor.dart'
    if (dart.library.js_interop) 'web_exception_event_processor.dart';

abstract class ExceptionEventProcessor implements EventProcessor {
  factory ExceptionEventProcessor(SentryOptions options) =>
      exceptionEventProcessor(options);
}
