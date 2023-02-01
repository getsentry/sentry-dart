import 'dart:async';

import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_exception_factory.dart';

/// This is an [EventProcessor], which improves crash reports of [DioError]s.
/// It adds information about [DioError.requestOptions] if present and also about
/// the inner exceptions.
class DioxEventProcessor implements EventProcessor {
  // Because of obfuscation, we need to dynamically get the name
  static final _dioErrorType = (DioError).toString();

  /// This is an [EventProcessor], which improves crash reports of [DioError]s.
  DioxEventProcessor(
    this._options,
    this._maxRequestBodySize,
    this._maxResponseBodySize,
  );

  final SentryOptions _options;
  final MaxRequestBodySize _maxRequestBodySize;

  // Will be used again, see https://github.com/getsentry/sentry-dart/issues/624
  // ignore: unused_field
  final MaxResponseBodySize _maxResponseBodySize;

  SentryExceptionFactory get _sentryExceptionFactory =>
      // ignore: invalid_use_of_internal_member
      _options.exceptionFactory;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {dynamic hint}) {
    final dynamic dioError = event.throwable;
    if (dioError is! DioError) {
      return event;
    }

    Contexts contexts = event.contexts;
    if (event.contexts.response == null) {
      contexts = contexts.copyWith(response: _responseFrom(dioError));
    }
    // Don't override just parts of the original request.
    // Keep the original one or if there's none create one.
    event = event.copyWith(
      request: event.request ?? _requestFrom(dioError),
      contexts: contexts,
    );

    final innerDioStackTrace = dioError.stackTrace;
    final innerDioErrorException = dioError.error;

    // If the inner errors stacktrace is null,
    // there's nothing to create chained exception
    if (innerDioStackTrace == null) {
      return event;
    }

    try {
      final innerException = _sentryExceptionFactory.getSentryException(
        innerDioErrorException ?? 'DioError inner stacktrace',
        stackTrace: innerDioStackTrace,
      );

      final exceptions = _removeDioErrorStackTraceFromValue(
        List<SentryException>.from(event.exceptions ?? <SentryException>[]),
        dioError,
      );

      return event.copyWith(
        exceptions: [
          innerException,
          ...exceptions,
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

  /// Remove the StackTrace from [dioError] so the message on Sentry looks
  /// much better.
  List<SentryException> _removeDioErrorStackTraceFromValue(
    List<SentryException> exceptions,
    DioError dioError,
  ) {
    final dioSentryExceptions =
        exceptions.where((element) => element.type == _dioErrorType);

    if (dioSentryExceptions.isEmpty) {
      return exceptions;
    }
    var dioSentryException = dioSentryExceptions.first;

    final exceptionIndex = exceptions.indexOf(dioSentryException);
    exceptions.remove(dioSentryException);

    // Remove error and stacktrace, so that the DioError value doesn't
    // include the chained exception.
    final effectiveDioError = DioError(
      requestOptions: dioError.requestOptions,
      response: dioError.response,
      type: dioError.type,
      message: dioError.message,
    );

    dioSentryException = dioSentryException.copyWith(
      value: effectiveDioError.toString(),
    );

    exceptions.insert(exceptionIndex, dioSentryException);

    return exceptions;
  }

  SentryRequest? _requestFrom(DioError dioError) {
    final options = dioError.requestOptions;
    final headers = options.headers
        .map((key, dynamic value) => MapEntry(key, value?.toString() ?? ''));

    return SentryRequest.fromUri(
      uri: options.uri,
      method: options.method,
      headers: _options.sendDefaultPii ? headers : null,
      data: _getRequestData(dioError.requestOptions.data),
    );
  }

  /// Returns the request data, if possible according to the users settings.
  Object? _getRequestData(dynamic data) {
    if (!_options.sendDefaultPii) {
      return null;
    }
    if (data is String) {
      if (_maxRequestBodySize.shouldAddBody(data.codeUnits.length)) {
        return data;
      }
    } else if (data is List<int>) {
      if (_maxRequestBodySize.shouldAddBody(data.length)) {
        return data;
      }
    }
    return null;
  }

  SentryResponse _responseFrom(DioError dioError) {
    final response = dioError.response;

    final headers = response?.headers.map.map(
      (key, value) => MapEntry(key, value.join('; ')),
    );

    return SentryResponse(
      headers: _options.sendDefaultPii ? headers : null,
      bodySize: dioError.response?.data?.length as int?,
      statusCode: response?.statusCode,
    );
  }
}
