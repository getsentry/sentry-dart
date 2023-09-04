import 'package:meta/meta.dart';
import 'contexts.dart';
import '../utils/iterable_utils.dart';

/// The response interface contains information on a HTTP request related to the event.
@immutable
class SentryResponse {
  /// The type of this class in the [Contexts] field
  static const String type = 'response';

  /// The size of the response body.
  final int? bodySize;

  /// The HTTP status code of the response.
  /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
  final int? statusCode;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  final Map<String, String>? _headers;

  /// Cookie key-value pairs as string.
  final String? cookies;

  final Object? _data;

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
    return SentryResponse(
      headers: json.containsKey('headers') ? Map.from(json['headers']) : null,
      cookies: json['cookies'],
      bodySize: json['body_size'],
      statusCode: json['status_code'],
      data: json['data'],
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

  SentryResponse clone() => SentryResponse(
        bodySize: bodySize,
        headers: headers,
        cookies: cookies,
        statusCode: statusCode,
        data: data,
      );
}
