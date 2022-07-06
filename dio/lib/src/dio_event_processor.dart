import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_exception_factory.dart';

/// This is an [EventProcessor], which improves crash reports of [DioError]s.
/// It adds information about [DioError.response] if present and also about
/// the inner exceptions.
class DioEventProcessor implements EventProcessor {
  // Because of obfuscation, we need to dynamically get the name
  static final _dioErrorType = (DioError).toString();

  /// This is an [EventProcessor], which improves crash reports of [DioError]s.
  DioEventProcessor(
    this._options,
    this._maxRequestBodySize,
    this._maxResponseBodySize,
  );

  final SentryOptions _options;
  final MaxRequestBodySize _maxRequestBodySize;
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

    final response = _responseFrom(dioError)?.toJson();
    Contexts? contexts;
    if (response != null && response.isNotEmpty) {
      contexts = event.contexts..[SentryResponse.type] = response;
    }

    // Don't override just parts of the original request.
    // Keep the original one or if there's none create one.
    event = event.copyWith(
      request: event.request ?? _requestFrom(dioError),
      contexts: contexts,
    );

    final innerDioStackTrace = dioError.stackTrace;
    final innerDioErrorException = dioError.error as Object?;

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
    dioError.stackTrace = null;
    dioError.error = null;

    dioSentryException = dioSentryException.copyWith(
      value: dioError.toString(),
    );

    exceptions.insert(exceptionIndex, dioSentryException);

    return exceptions;
  }

  SentryRequest? _requestFrom(DioError dioError) {
    final options = dioError.requestOptions;
    // As far as I can tell there's no way to get the uri without the query part
    // so we replace it with an empty string.
    final urlWithoutQuery = options.uri.replace(query: '').toString();

    final query = options.uri.query.isEmpty ? null : options.uri.query;

    final headers = options.headers
        .map((key, dynamic value) => MapEntry(key, value?.toString() ?? ''));

    return SentryRequest(
      method: options.method,
      headers: _options.sendDefaultPii ? headers : null,
      url: urlWithoutQuery,
      queryString: query,
      cookies: _options.sendDefaultPii
          ? options.headers['Cookie']?.toString()
          : null,
      data: _getRequestData(dioError.response?.data),
    );
  }

  /// Returns the request data, if possible according to the users settings.
  /// Type checks are based on DIOs [ResponseType].
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

  SentryResponse? _responseFrom(DioError dioError) {
    final response = dioError.response;

    final headers = response?.headers.map.map(
      (key, value) => MapEntry(key, value.join('; ')),
    );

    return SentryResponse(
      headers: _options.sendDefaultPii ? headers : null,
      url: response?.realUri.toString(),
      redirected: response?.isRedirect,
      body: _getResponseData(dioError.response?.data),
    );
  }

  /// Returns the request data, if possible according to the users settings.
  /// Type checks are based on DIOs [ResponseType].
  Object? _getResponseData(dynamic data) {
    if (!_options.sendDefaultPii) {
      return null;
    }
    if (data is String) {
      if (_maxResponseBodySize.shouldAddBody(data.codeUnits.length)) {
        return data;
      }
    } else if (data is List<int>) {
      if (_maxResponseBodySize.shouldAddBody(data.length)) {
        return data;
      }
    }
    return null;
  }
}
