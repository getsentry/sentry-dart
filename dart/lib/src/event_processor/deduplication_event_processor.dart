import 'dart:async';
import 'dart:collection';
import '../event_processor.dart';
import '../protocol.dart';
import '../sentry_options.dart';

const eventsToKeepForDeduplication = 20;

/// Deduplicates events with the same [SentryEvent.throwable].
/// It keeps track of the last [eventsToKeepForDeduplication]
/// events. Older events aren't considered for deduplication.
///
/// Only [SentryEvent]s with exceptions are considered for deduplication.
/// [SentryEvent]s without exceptions aren't deduplicated.
///
/// Caveats:
/// It does not work in the following case:
/// ```dart
/// var fooOne = Exception('foo');
/// var fooTwo = Exception('foo');
/// ```
/// because (fooOne == fooTwo) equals false
class DeduplicationEventProcessor extends EventProcessor {
  DeduplicationEventProcessor(this._options);

  final LinkedHashSet<Object> _exceptionToDeduplicate = LinkedHashSet<Object>();
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
    if (_exceptionToDeduplicate.contains(exception)) {
      _options.logger(
        SentryLevel.debug,
        'Duplicate Exception detected. '
        'Event ${event.eventId} will be discarded.',
      );
      return null;
    }
    // No duplication detected
    _exceptionToDeduplicate.add(exception);
    if (_exceptionToDeduplicate.length > eventsToKeepForDeduplication) {
      _exceptionToDeduplicate.remove(_exceptionToDeduplicate.last);
    }
    return event;
  }
}
