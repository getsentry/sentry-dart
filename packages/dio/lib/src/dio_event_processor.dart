// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'dart:convert';

/// Prose for the failure types that arrive without a status code. Only the
/// types whose enum name reads badly are listed; anything else, including a type
/// Dio adds in a future minor release, falls back to the name itself.
const _failureDescriptions = <DioExceptionType, String>{
  DioExceptionType.connectionTimeout: 'connection timeout',
  DioExceptionType.sendTimeout: 'send timeout',
  DioExceptionType.receiveTimeout: 'receive timeout',
  DioExceptionType.badCertificate: 'bad certificate',
  DioExceptionType.connectionError: 'connection error',
  DioExceptionType.badResponse: 'bad response',
  DioExceptionType.cancel: 'cancelled',
};

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

    for (final exception in event.exceptions ?? <SentryException>[]) {
      final throwable = exception.throwable;
      if (throwable is DioError) {
        if (_shouldReplaceValue(throwable)) {
          exception.value = _valueFrom(throwable);
        }
        dioError ??= throwable;
      }
    }

    if (dioError == null) {
      return event;
    }

    final response = _responseFrom(dioError);
    hint.response ??= response;

    // Don't override just parts of the original request.
    // Keep the original one or if there's none create one.
    event.request = event.request ?? _requestFrom(dioError);
    // Also on the event, not just the hint: a hint is beforeSend-only and never
    // serialized, so otherwise the status code, headers and body never arrive.
    event.contexts.response = event.contexts.response ?? response;
    return event;
  }

  /// Dio's own messages are paragraphs of remediation advice rather than facts:
  /// a bad response explains what the status code means and links to MDN, and a
  /// timeout restates the timeout that was configured. sentry-javascript
  /// likewise never surfaces the underlying error's message, only the synthetic
  /// one.
  bool _shouldReplaceValue(DioError dioError) {
    // Never override a message the user chose to build themselves.
    return dioError.stringBuilder == null &&
        DioException.readableStringBuilder ==
            defaultDioExceptionReadableStringBuilder;
  }

  /// Worded like the other SDKs' HTTP client errors so a Dio 502 and a
  /// `package:http` 502 read the same. The route is deliberately left out — it
  /// already travels on [SentryEvent.request] and would make the issue title
  /// vary per path parameter. The untouched [DioError] stays on
  /// [SentryException.throwable] for `beforeSend`.
  String _valueFrom(DioError dioError) {
    final statusCode = dioError.response?.statusCode;
    if (statusCode != null) {
      return 'HTTP Client Error with status code: $statusCode';
    }
    final failure = _failureDescriptions[dioError.type] ?? dioError.type.name;
    return 'HTTP Client Error: $failure';
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
      // For all strings, use UTF-8 encoding for accurate size validation
      if (_canEncodeStringWithinLimit(
        data,
        // ignore: invalid_use_of_internal_member
        hardLimit: _options.maxRequestBodySize.getSizeLimit(),
      )) {
        return data;
      }
    }
    // For List<int> data (including Uint8List), we have exact size information
    else if (data is List<int>) {
      if (_options.maxRequestBodySize.shouldAddBody(data.length)) {
        return data;
      }
    } else if (data is num || data is bool) {
      if (_options.maxRequestBodySize != MaxRequestBodySize.never) {
        return data;
      }
    } else if (Transformer.isJsonMimeType(requestOptions.contentType)) {
      if (_canEncodeJsonWithinLimit(
        data,
        // ignore: invalid_use_of_internal_member
        hardLimit: _options.maxRequestBodySize.getSizeLimit(),
      )) {
        return data;
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

    // ignore: invalid_use_of_internal_member
    final sanitizedHeaders = HttpSanitizer.sanitizedHeaders(headers);
    // Read explicitly because sanitizing strips `set-cookie` before
    // SentryResponse can pick it up.
    final setCookie = headers?['set-cookie'];

    return SentryResponse(
      headers: _options.sendDefaultPii ? sanitizedHeaders : null,
      cookies: _options.sendDefaultPii ? setCookie : null,
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

/// Returns true if the data can be encoded as JSON within the given byte limit.
bool _canEncodeJsonWithinLimit(Object? data, {int? hardLimit}) {
  if (hardLimit == null) {
    // No limit means always allow
    return true;
  }
  if (hardLimit == 0) {
    // Zero limit means never allow
    return false;
  }

  // Only proceed with encoding if we have a positive limit
  final sink = _CountingByteSink(hardLimit);
  final conv = JsonUtf8Encoder().startChunkedConversion(sink);
  try {
    conv.add(data);
    conv.close();
    return true;
  } on _SizeLimitExceeded {
    return false;
  } catch (_) {
    return false;
  }
}

/// Returns true if the string can be encoded as UTF-8 within the given byte limit.
bool _canEncodeStringWithinLimit(String data, {int? hardLimit}) {
  if (hardLimit == null) {
    // No limit means always allow
    return true;
  }
  if (hardLimit == 0) {
    // Zero limit means never allow
    return false;
  }

  // Only proceed with encoding if we have a positive limit
  final utf8Bytes = utf8.encode(data);
  return utf8Bytes.length <= hardLimit;
}

/// Exception thrown when the hard limit is exceeded during counting.
class _SizeLimitExceeded implements Exception {}

/// A sink that counts bytes without storing them, with an optional hard limit.
class _CountingByteSink implements Sink<List<int>> {
  int count = 0;
  final int? hardLimit;
  _CountingByteSink([this.hardLimit]);

  @override
  void add(List<int> chunk) {
    count += chunk.length;
    if (hardLimit != null && count > hardLimit!) {
      throw _SizeLimitExceeded();
    }
  }

  @override
  void close() {}
}
