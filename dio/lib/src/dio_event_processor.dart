// ignore_for_file: deprecated_member_use

import 'dart:convert';

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
  SentryEvent? apply(SentryEvent event, Hint hint) {
    if (event is SentryTransaction) {
      return event;
    }

    DioError? dioError;

    for (final exception in event.exceptions ?? []) {
      final throwable = exception.throwable;
      if (throwable is DioError) {
        dioError = throwable;
        break;
      }
    }

    if (dioError == null) {
      return event;
    }

    final response = _responseFrom(dioError);

    var contexts = event.contexts;
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
  Object? _getRequestData(Object? data) {
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
      bodySize: _getBodySize(
        dioError.response?.data,
        dioError.requestOptions.responseType,
      ),
      statusCode: response?.statusCode,
      data: _getResponseData(
        dioError.response?.data,
        dioError.requestOptions.responseType,
      ),
    );
  }

  /// Returns the response data, if possible according to the users settings.
  Object? _getResponseData(Object? data, ResponseType responseType) {
    if (!_options.sendDefaultPii || data == null) {
      return null;
    }
    switch (responseType) {
      case ResponseType.json:
        // ignore: invalid_use_of_internal_member
        final jsData = utf8JsonEncoder.convert(data);
        if (_options.maxResponseBodySize.shouldAddBody(jsData.length)) {
          return data;
        }
        break;
      case ResponseType.stream:
        break; // No support for logging stream body.
      case ResponseType.plain:
        if (data is String &&
            _options.maxResponseBodySize.shouldAddBody(data.codeUnits.length)) {
          return data;
        }
        break;
      case ResponseType.bytes:
        if (data is List<int> &&
            _options.maxResponseBodySize.shouldAddBody(data.length)) {
          return data;
        }
        break;
    }
    return null;
  }

  int? _getBodySize(Object? data, ResponseType responseType) {
    if (data == null) {
      return null;
    }
    switch (responseType) {
      case ResponseType.json:
        return json.encode(data).codeUnits.length;
      case ResponseType.stream:
        if (data is String) {
          return data.length;
        } else {
          return null;
        }
      case ResponseType.plain:
        if (data is String) {
          return data.codeUnits.length;
        } else {
          return null;
        }
      case ResponseType.bytes:
        if (data is List<int>) {
          return data.length;
        } else {
          return null;
        }
    }
  }
}
