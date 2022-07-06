import 'package:meta/meta.dart';

/// The response interface contains information on a HTTP request related to the event.
/// This is an experimental feature. It might be removed at any time.
@experimental
@immutable
class SentryResponse {
  /// The tpye of this class in the [Contexts] field
  static String type = 'response';

  /// The URL of the response if available.
  /// Might be the redirected URL
  final String? url;

  /// Indicates whether or not the response is the result of a redirect
  /// (that is, its URL list has more than one entry).
  final bool? redirected;

  final Object? body;

  final Map<String, String>? _headers;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  final Map<String, String>? _other;

  Map<String, String> get other => Map.unmodifiable(_other ?? const {});

  SentryResponse({
    this.url,
    this.body,
    this.redirected,
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
    };
  }

  SentryResponse copyWith({
    String? url,
    Map<String, String>? headers,
    Map<String, String>? other,
    bool? redirected,
    Object? body,
  }) =>
      SentryResponse(
        url: url ?? this.url,
        headers: headers ?? _headers,
        redirected: redirected ?? this.redirected,
        other: other ?? _other,
        body: body ?? this.body,
      );
}
