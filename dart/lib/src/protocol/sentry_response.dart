import 'package:meta/meta.dart';
import 'contexts.dart';

/// The response interface contains information on a HTTP request related to the event.
/// This is an experimental feature. It might be removed at any time.
@experimental
@immutable
class SentryResponse {
  /// The tpye of this class in the [Contexts] field
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

  SentryResponse({
    this.bodySize,
    this.statusCode,
    Map<String, String>? headers,
  }) : _headers = headers != null ? Map.from(headers) : null;

  /// Deserializes a [SentryResponse] from JSON [Map].
  factory SentryResponse.fromJson(Map<String, dynamic> json) {
    return SentryResponse(
        headers: json.containsKey('headers') ? Map.from(json['headers']) : null,
        bodySize: json['body_size'],
        statusCode: json['status_code']);
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (headers.isNotEmpty) 'headers': headers,
      if (bodySize != null) 'body_size': bodySize,
      if (statusCode != null) 'status_code': statusCode,
    };
  }

  SentryResponse copyWith({
    int? statusCode,
    int? bodySize,
    Map<String, String>? headers,
  }) =>
      SentryResponse(
        headers: headers ?? _headers,
        bodySize: bodySize ?? this.bodySize,
        statusCode: statusCode ?? this.statusCode,
      );

  SentryResponse clone() => SentryResponse(
        bodySize: bodySize,
        headers: headers,
        statusCode: statusCode,
      );
}
