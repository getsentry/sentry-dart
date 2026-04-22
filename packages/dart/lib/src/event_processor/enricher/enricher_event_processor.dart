import '../../event_processor.dart';
import '../../protocol.dart';
import '../../sentry_options.dart';
import 'io_enricher_event_processor.dart'
    if (dart.library.js_interop) 'web_enricher_event_processor.dart';

abstract class EnricherEventProcessor implements EventProcessor {
  factory EnricherEventProcessor(SentryOptions options) =>
      enricherEventProcessor(options);

  /// Returns a fresh [Contexts] containing this enricher's platform-derived
  /// data.
  ///
  /// Used by telemetry callbacks to project enricher data onto span, log,
  /// and metric attributes (via [Contexts.toAttributes]). [apply] continues
  /// to perform its own field-level merge into `event.contexts` for events.
  Future<Contexts> buildContexts();
}
