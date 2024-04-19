import 'dart:collection';
import '../event_processor.dart';
import '../hint.dart';
import '../protocol.dart';
import '../sentry_options.dart';

/// Deduplicates events with the same [SentryEvent.throwable].
/// It keeps track of the last [SentryOptions.maxDeduplicationItems]
/// events. Older events aren't considered for deduplication.
///
/// Only [SentryEvent]s where [SentryEvent.throwable] is not null are considered
/// for deduplication. [SentryEvent]s without exceptions aren't deduplicated.
///
/// Caveats:
/// It does not work in the following case:
/// ```dart
/// var fooOne = Exception('foo');
/// var fooTwo = Exception('foo');
/// ```
/// because (fooOne == fooTwo) equals false
class DeduplicationEventProcessor implements EventProcessor {
  DeduplicationEventProcessor(this._options);

  // Using a HashSet makes this performant.
  final Queue<int> _exceptionToDeduplicate = Queue<int>();
  final SentryOptions _options;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    if (event is SentryTransaction) {
      return event;
    }

    if (!_options.enableDeduplication) {
      _options.logger(SentryLevel.debug, 'Deduplication is disabled');
      return event;
    }
    return _deduplicate(event);
  }

  SentryEvent? _deduplicate(SentryEvent event) {
    // Cast to `Object?` in order to enable better type checking
    // because `event.throwable` is `dynamic`
    final exception = event.throwable as Object?;

    if (exception == null) {
      // If no exception is given, just return the event
      return event;
    }

    // Just use the hashCode, to keep the memory footprint small
    final exceptionHashCode = exception.hashCode;

    if (_exceptionToDeduplicate.contains(exceptionHashCode)) {
      _options.logger(
        SentryLevel.info,
        'Duplicated exception detected. '
        'Event ${event.eventId} will be discarded.',
      );
      return null;
    }

    // No duplication detected
    _exceptionToDeduplicate.add(exceptionHashCode);
    if (_exceptionToDeduplicate.length > _options.maxDeduplicationItems) {
      _exceptionToDeduplicate.removeFirst();
    }
    return event;
  }
}
