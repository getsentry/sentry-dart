// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'dart:convert';
import 'dart:typed_data';

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

    return SentryRequest.fromUri(
      uri: options.uri,
      method: options.method,
      headers: _options.sendDefaultPii ? headers : null,
      data: _getRequestData(dioError.requestOptions.data, options),
    );
  }

  /// Returns the request data, if possible according to the users settings.
  /// Takes into account the content type to determine proper encoding.
  ///
  Object? _getRequestData(Object? data, RequestOptions requestOptions) {
    if (!_options.sendDefaultPii || data == null) {
      return null;
    }

    // Handle different data types based on Dio's encoding behavior and content type
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
    } else if (data is Uint8List) {
      // Handle Uint8List (typed byte array)
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
        return data;
      }
    } else if (data is num || data is bool) {
      if (_options.maxRequestBodySize != MaxRequestBodySize.never) {
        return data;
      }
    } else if (data is! String &&
        Transformer.isJsonMimeType(requestOptions.contentType)) {
      try {
        final jsonSize = jsonEncode(data).codeUnits.length;
        if (_options.maxRequestBodySize.shouldAddBody(jsonSize)) {
          return data;
        }
      } catch (e) {
        return null;
      }
    } else if (data is FormData) {
      // FormData has a built-in length property for size checking
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
        return _convertFormDataToMap(data);
      }
    } else if (data is MultipartFile) {
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
        return _convertMultipartFileToMap(data);
      }
    }

    return null;
  }

  /// Converts FormData to a map representation that SentryRequest can handle
  Map<String, dynamic> _convertFormDataToMap(FormData formData) {
    final result = <String, dynamic>{};

    // Add form fields - ensure proper typing
    for (final field in formData.fields) {
      result[field.key] = field.value;
    }

    // Add file information (metadata only, not the actual file content)
    for (final file in formData.files) {
      result['${file.key}_file'] = _convertMultipartFileToMap(file.value);
    }

    return result;
  }

  /// Converts a MultipartFile to a map representation that SentryRequest can handle
  Map<String, dynamic> _convertMultipartFileToMap(MultipartFile file) {
    final result = <String, dynamic>{
      'filename': file.filename,
      'contentType': file.contentType?.toString(),
      'length': file.length,
    };

    // Only add headers if they exist and are not empty
    if (file.headers != null && file.headers!.isNotEmpty) {
      // Convert headers to a proper Map<String, dynamic>
      final headersMap = <String, dynamic>{};
      for (final entry in file.headers!.entries) {
        headersMap[entry.key] = entry.value;
      }
      result['headers'] = headersMap;
    }

    return result;
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
