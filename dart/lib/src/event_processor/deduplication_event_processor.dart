import 'dart:async';
import '../event_processor.dart';
import '../protocol.dart';
import '../sentry_options.dart';

const eventsToKeepForDeduplication = 20;

/// Deduplicates events with the same [SentryEvent.throwable].
/// It keeps track of the last [eventsToKeepForDeduplication]
/// events. Older events aren't considered for deduplication.
/// This is a hard
/// Caveats:
/// It does not work in the following case:
/// ```dart
/// var fooOne = Exception('foo');
/// var fooTwo = Exception('foo');
/// ```
/// because (fooOne == fooTwo) equals false
class DeduplicationEventProcessor extends EventProcessor {
  DeduplicationEventProcessor(this._options);

  // Map from exception to object
  final Map<Object, Object?> exceptionMap = {};
  final SentryOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) {
    if (!_options.enableDeduplication) {
      _options.logger(SentryLevel.debug, 'Deduplication is disabled');
      return event;
    }
    return _deduplicate(event);
  }

  FutureOr<SentryEvent?> _deduplicate(SentryEvent event) {
    // cast to Object? in order to enable better type checking
    final exception = event.throwable as Object?;
    if (exception == null) {
      // If no exception is given, just return the event
      return event;
    }
    if (exceptionMap.containsKey(exception)) {
      _options.logger(
        SentryLevel.debug,
        'Duplicate Exception detected. Event ${event.eventId} will be discarded.',
      );
      return null;
    }
    // No duplication detected
    exceptionMap[exception] = null;
    if (exceptionMap.length > eventsToKeepForDeduplication) {
      exceptionMap.remove(exceptionMap.entries.last.key);
    }
    return event;
  }
}
