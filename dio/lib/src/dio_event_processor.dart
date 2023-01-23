import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// This is an [EventProcessor], which improves crash reports of [DioError]s.
/// It adds information about [DioError.requestOptions] if present and also about
/// the inner exceptions.
class DioEventProcessor implements EventProcessor {
  /// This is an [EventProcessor], which improves crash reports of [DioError]s.
  DioEventProcessor(this._options);

  final SentryOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {Hint? hint}) {
    final exceptions = event.exceptions;
    if (exceptions == null || exceptions.isEmpty) {
      return event;
    }
    final dynamic dioError = exceptions.first.throwable;
    if (dioError is! DioError) {
      return event;
    }

    final response = _responseFrom(dioError);

    Contexts contexts = event.contexts;
    if (event.contexts.response == null) {
      contexts = contexts.copyWith(response: response);
    }
    // Don't override just parts of the original request.
    // Keep the original one or if there's none create one.
    event = event.copyWith(
      request: event.request ?? _requestFrom(dioError),
      contexts: contexts,
    );

    return event;
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
      if (_options.maxRequestBodySize.shouldAddBody(data.codeUnits.length)) {
        return data;
      }
    } else if (data is List<int>) {
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
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
