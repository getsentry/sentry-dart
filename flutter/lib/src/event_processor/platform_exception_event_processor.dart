import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

/// Add code & message from [PlatformException] to [SentryException]
class PlatformExceptionEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    if (event is SentryTransaction) {
      return event;
    }

    final exceptions = <SentryException>[];

    for (SentryException exception in (event.exceptions ?? [])) {
      final platformException = exception.throwable;
      if (platformException is PlatformException) {
        exception = _enrich(exception, platformException);
      }
      exceptions.add(exception);
    }

    return event.copyWith(exceptions: exceptions);
  }

  SentryException _enrich(
      SentryException sentryException, PlatformException platformException) {
    final data = Map<String, dynamic>.from(
      sentryException.mechanism?.data ?? {},
    );
    data['code'] = platformException.code;
    if (platformException.message != null) {
      data['message'] = platformException.message;
    }
    final mechanism =
        sentryException.mechanism ?? Mechanism(type: "platformException");
    return sentryException.copyWith(
      mechanism: mechanism.copyWith(data: data),
    );
  }
}
