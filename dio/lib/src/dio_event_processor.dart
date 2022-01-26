// ignore_for_file: implementation_imports, public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';

class DioEventProcessor extends EventProcessor {
  DioEventProcessor(this._options);

  final SentryOptions _options;
  late final sentryExceptionFactory = SentryExceptionFactory(
    _options,
    SentryStackTraceFactory(_options),
  );

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {dynamic hint}) {
    final dynamic dioError = event.throwable;
    if (dioError is! DioError) {
      return event;
    }

    // Potential further improvements:
    // Add dioError.requestOptions to event.extra
    // Add dioError.response to event.extra

    try {
      final exception = sentryExceptionFactory.getSentryException(
        dioError.error,
        stackTrace: dioError.stackTrace,
      );

      final exceptions = event.exceptions;

      return event.copyWith(
        exceptions: [
          exception,
          if (exceptions != null) ...exceptions,
        ],
      );
    } catch (e, stackTrace) {
      _options.logger(
        SentryLevel.debug,
        'Could not convert DioError to SentryException',
        exception: e,
        stackTrace: stackTrace,
      );
    }
    return event;
  }
}
