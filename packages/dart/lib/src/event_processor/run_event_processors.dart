import 'package:meta/meta.dart';

import '../client_reports/discard_reason.dart';
import '../debug_logger.dart';
import '../event_processor.dart';
import '../hint.dart';
import '../protocol/sentry_event.dart';
import '../protocol/sentry_transaction.dart';
import '../sentry_options.dart';
import '../transport/data_category.dart';

@internal
Future<SentryEvent?> runEventProcessors(
  SentryEvent event,
  Hint hint,
  List<EventProcessor> eventProcessors,
  SentryOptions options,
) async {
  int spanCountBeforeEventProcessors =
      event is SentryTransaction ? event.spans.length : 0;

  SentryEvent? processedEvent = event;
  for (final processor in eventProcessors) {
    try {
      final e = processor.apply(processedEvent!, hint);
      processedEvent = e is Future<SentryEvent?> ? await e : e;
    } catch (exception, stackTrace) {
      debugLogger.error(
        'An exception occurred while processing event by a processor',
        category: 'event_processor',
        error: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }

    final discardReason = DiscardReason.eventProcessor;
    if (processedEvent == null) {
      options.recorder.recordLostEvent(discardReason, _getCategory(event));
      if (event is SentryTransaction) {
        // We dropped the whole transaction, the dropped count includes all child spans + 1 root span
        options.recorder.recordLostEvent(
          discardReason,
          DataCategory.span,
          count: spanCountBeforeEventProcessors + 1,
        );
      }
      debugLogger.debug('Event was dropped by a processor', category: 'event_processor');
      break;
    } else if (event is SentryTransaction &&
        processedEvent is SentryTransaction) {
      // If event processor removed only some spans we still report them as dropped
      final spanCountAfterEventProcessors = processedEvent.spans.length;
      final droppedSpanCount =
          spanCountBeforeEventProcessors - spanCountAfterEventProcessors;
      if (droppedSpanCount > 0) {
        options.recorder.recordLostEvent(
          discardReason,
          DataCategory.span,
          count: droppedSpanCount,
        );
      }
    }
  }

  return processedEvent;
}

DataCategory _getCategory(SentryEvent event) {
  if (event is SentryTransaction) {
    return DataCategory.transaction;
  } else if (event.type == 'feedback') {
    return DataCategory.feedback;
  } else {
    return DataCategory.error;
  }
}
