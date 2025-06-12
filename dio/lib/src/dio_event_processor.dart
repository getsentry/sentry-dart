// ignore_for_file: deprecated_member_use

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

    hint.response ??= _responseFrom(dioError);

    // Don't override just parts of the original request.
    // Keep the original one or if there's none create one.
    event.request = event.request ?? _requestFrom(dioError);
    return event;
  }

  SentryRequest? _requestFrom(DioError dioError) {
    final options = dioError.requestOptions;
    final headers = options.headers
        .map((key, dynamic value) => MapEntry(key, value?.toString() ?? ''));

    // Get content length from request headers (similar to response handling)
    final contentLength = _getRequestContentLength(options.headers);
    final requestData = _getRequestData(dioError.requestOptions.data);
    
    // Apply content-length filtering if we have both content-length and data
    final filteredData = _filterDataByContentLength(requestData, contentLength);

    return SentryRequest.fromUri(
      uri: options.uri,
      method: options.method,
      headers: _options.sendDefaultPii ? headers : null,
      data: filteredData,
    );
  }

  /// Returns the request data, if possible according to the users settings.
  Object? _getRequestData(Object? data) {
    if (!_options.sendDefaultPii) {
      return null;
    }
    
    // For String data, we have exact size information
    if (data is String) {
      if (_options.maxRequestBodySize.shouldAddBody(data.codeUnits.length)) {
        return data;
      }
    } 
    // For List<int> data, we have exact size information
    else if (data is List<int>) {
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
        return data;
      }
    }
    // For other data types (Map, List, primitives), check if we have content-length from headers
    else if (data != null) {
      return data; // Include data and let content-length from headers determine if it should be sent
    }
    
    return null;
  }

  /// Extract content-length from request headers
  int? _getRequestContentLength(Map<String, dynamic> headers) {
    // Convert headers to the format expected by HttpHeaderUtils
    final convertedHeaders = <String, List<String>>{};
    headers.forEach((key, value) {
      convertedHeaders[key] = [value?.toString() ?? ''];
    });
    
    // ignore: invalid_use_of_internal_member
    return HttpHeaderUtils.getContentLength(convertedHeaders);
  }
  
  /// Filter data based on content-length and maxRequestBodySize settings
  Object? _filterDataByContentLength(Object? data, int? contentLength) {
    if (data == null) {
      return null;
    }
    
    // If we have content-length from headers, use it for size checking
    if (contentLength != null) {
      if (!_options.maxRequestBodySize.shouldAddBody(contentLength)) {
        return null; // Data too large according to content-length
      }
    }
    
    return data;
  }

  SentryResponse _responseFrom(DioError dioError) {
    final response = dioError.response;

    final headers = response?.headers.map.map(
      (key, value) => MapEntry(key, value.join('; ')),
    );
    final contentLengthHeader = headers?['content-length'];
    int? contentLength;
    if (contentLengthHeader != null) {
      contentLength = int.tryParse(contentLengthHeader);
    }

    return SentryResponse(
      headers: _options.sendDefaultPii ? headers : null,
      bodySize: contentLength,
      statusCode: response?.statusCode,
      data: _getResponseData(dioError.response?.data, contentLength),
    );
  }

  Object? _getResponseData(Object? data, int? contentLength) {
    if (!_options.sendDefaultPii || data == null) {
      return null;
    }
    if (contentLength == null) {
      return null;
    }
    // ignore: invalid_use_of_internal_member
    if (contentLength > Hint.maxResponseBodySize) {
      return null;
    }
    return data;
  }
}
