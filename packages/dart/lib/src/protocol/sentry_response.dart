import 'contexts.dart';
import '../utils/iterable_utils.dart';
import '../utils/type_safe_map_access.dart';

/// The response interface contains information on a HTTP request related to the event.
class SentryResponse {
  /// The type of this class in the [Contexts] field
  static const String type = 'response';

  /// The size of the response body.
  int? bodySize;

  /// The HTTP status code of the response.
  /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
  int? statusCode;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  Map<String, String>? _headers;

  /// Cookie key-value pairs as string.
  String? cookies;

  Object? _data;

  /// Response data in any format that makes sense.
  ///
  /// SDKs should discard large and binary bodies by default.
  /// Can be given as a string or structural data of any format.
  Object? get data {
    final typedData = _data;
    if (typedData is List) {
      return List.unmodifiable(typedData);
    } else if (typedData is Map) {
      return Map.unmodifiable(typedData);
    }

    return _data;
  }

  SentryResponse({
    this.bodySize,
    this.statusCode,
    Map<String, String>? headers,
    String? cookies,
    Object? data,
  })  : _data = data,
        _headers = headers != null ? Map.from(headers) : null,
        // Look for a 'Set-Cookie' header (case insensitive) if not given.
        cookies = cookies ??
            IterableUtils.firstWhereOrNull(
              headers?.entries,
              (MapEntry<String, String> e) =>
                  e.key.toLowerCase() == 'set-cookie',
            )?.value;

  /// Deserializes a [SentryResponse] from JSON [Map].
  factory SentryResponse.fromJson(Map<String, dynamic> json) {
    final headersJson = json.getValueOrNull<Map<String, dynamic>>('headers');
    return SentryResponse(
      headers:
          headersJson == null ? null : Map<String, String>.from(headersJson),
      cookies: json.getValueOrNull('cookies'),
      bodySize: json.getValueOrNull('body_size'),
      statusCode: json.getValueOrNull('status_code'),
      data: json.getValueOrNull('data'),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (headers.isNotEmpty) 'headers': headers,
      if (cookies != null) 'cookies': cookies,
      if (bodySize != null) 'body_size': bodySize,
      if (statusCode != null) 'status_code': statusCode,
      if (data != null) 'data': data,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryResponse copyWith({
    int? statusCode,
    int? bodySize,
    Map<String, String>? headers,
    String? cookies,
    Object? data,
  }) =>
      SentryResponse(
        headers: headers ?? _headers,
        cookies: cookies ?? this.cookies,
        bodySize: bodySize ?? this.bodySize,
        statusCode: statusCode ?? this.statusCode,
        data: data ?? this.data,
      );

  @Deprecated('Will be removed in a future version.')
  SentryResponse clone() => SentryResponse(
        bodySize: bodySize,
        headers: headers,
        cookies: cookies,
        statusCode: statusCode,
        data: data,
      );
}
