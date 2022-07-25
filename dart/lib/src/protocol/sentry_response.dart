import 'package:meta/meta.dart';
import 'contexts.dart';

/// The response interface contains information on a HTTP request related to the event.
/// This is an experimental feature. It might be removed at any time.
@experimental
@immutable
class SentryResponse {
  /// The tpye of this class in the [Contexts] field
  static const String type = 'response';

  /// The URL of the response if available.
  /// This might be the redirected URL
  final String? url;

  /// Indicates whether or not the response is the result of a redirect
  /// (that is, its URL list has more than one entry).
  final bool? redirected;

  /// The body of the response
  final Object? body;

  /// The HTTP status code of the response.
  /// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
  final int? statusCode;

  /// The status message for the corresponding [statusCode]
  final String? status;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  final Map<String, String>? _headers;

  Map<String, String> get other => Map.unmodifiable(_other ?? const {});

  final Map<String, String>? _other;

  SentryResponse({
    this.url,
    this.body,
    this.redirected,
    this.statusCode,
    this.status,
    Map<String, String>? headers,
    Map<String, String>? other,
  })  : _headers = headers != null ? Map.from(headers) : null,
        _other = other != null ? Map.from(other) : null;

  /// Deserializes a [SentryResponse] from JSON [Map].
  factory SentryResponse.fromJson(Map<String, dynamic> json) {
    return SentryResponse(
      url: json['url'],
      headers: json['headers'],
      other: json['other'],
      body: json['body'],
      statusCode: json['status_code'],
      status: json['status'],
      redirected: json['redirected'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (url != null) 'url': url,
      if (headers.isNotEmpty) 'headers': headers,
      if (other.isNotEmpty) 'other': other,
      if (redirected != null) 'redirected': redirected,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (statusCode != null) 'status_code': statusCode,
    };
  }

  SentryResponse copyWith({
    String? url,
    bool? redirected,
    int? statusCode,
    String? status,
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? other,
  }) =>
      SentryResponse(
        url: url ?? this.url,
        headers: headers ?? _headers,
        redirected: redirected ?? this.redirected,
        other: other ?? _other,
        body: body ?? this.body,
        status: status ?? this.status,
        statusCode: statusCode ?? this.statusCode,
      );

  SentryResponse clone() => SentryResponse(
        body: body,
        headers: headers,
        other: other,
        redirected: redirected,
        status: status,
        statusCode: statusCode,
        url: url,
      );
}
