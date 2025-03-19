import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

/// Add code & message from [PlatformException] to [SentryException]
class ExceptionGroupEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final sentryExceptions = event.exceptions ?? [];
    if (sentryExceptions.isEmpty) {
      return event;
    }

    final updatedSentryExceptions = <SentryException>[];

    int exceptionId = sentryExceptions.length - 1;

    for (SentryException sentryException in sentryExceptions.reversed) {
      final mechanism = sentryException.mechanism ?? Mechanism(type: "generic");

      final isChild = exceptionId > 0;
      final isOriginal = !isChild;

      sentryException = sentryException.copyWith(
        mechanism: mechanism.copyWith(
          type: isChild ? 'chained' : null,
          isExceptionGroup: isOriginal ? true : null,
          exceptionId: exceptionId,
          parentId: isChild ? exceptionId - 1 : null,
        ),
      );
      updatedSentryExceptions.add(sentryException);

      exceptionId -= 1;
    }

    return event.copyWith(exceptions: updatedSentryExceptions);
  }
}
