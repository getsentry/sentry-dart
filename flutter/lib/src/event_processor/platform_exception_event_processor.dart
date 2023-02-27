import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

/// Add code & message from [PlatformException] to [SentryException]
class PlatformExceptionEventProcessor implements EventProcessor {
  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {Hint? hint}) {
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
    data['platformException'] = {'code': platformException.code};
    if (platformException.message != null) {
      data['platformException']['message'] = platformException.message;
    }
    return sentryException.copyWith(
      mechanism: sentryException.mechanism?.copyWith(data: data),
    );
  }
}
