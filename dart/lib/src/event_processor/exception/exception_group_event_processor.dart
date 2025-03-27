import '../../event_processor.dart';
import '../../protocol.dart';
import '../../hint.dart';

/// Group exceptions into a flat list with references to hierarchy.
class ExceptionGroupEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final sentryExceptions = event.exceptions ?? [];
    if (sentryExceptions.isEmpty) {
      return event;
    }
    final firstException = sentryExceptions.first;

    if (sentryExceptions.length > 1 || firstException.exceptions == null) {
      // If already a list or no child exceptions, no grouping possible/needed.
      return event;
    } else {
      final grouped = firstException.flatten().reversed.toList(growable: false);
      return event.copyWith(exceptions: grouped);
    }
  }
}
