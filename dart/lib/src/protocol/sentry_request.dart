import 'package:meta/meta.dart';

/// The Request interface contains information on a HTTP request related to the event.
/// In client SDKs, this can be an outgoing request, or the request that rendered the current web page.
/// On server SDKs, this could be the incoming web request that is being handled.
@immutable
class SentryRequest {
  ///The URL of the request if available.
  ///The query string can be declared either as part of the url,
  ///or separately in queryString.
  final String? url;

  ///The HTTP method of the request.
  final String? method;

  /// The query string component of the URL.
  ///
  /// If the query string is not declared and part of the url parameter,
  /// Sentry moves it to the query string.
  final String? queryString;

  /// The cookie values as string.
  final String? cookies;

  final dynamic _data;

  /// Submitted data in a format that makes the most sense.
  /// SDKs should discard large bodies by default.
  /// Can be given as string or structural data of any format.
  dynamic get data {
    if (_data is List) {
      return List.unmodifiable(_data);
    } else if (_data is Map) {
      return Map.unmodifiable(_data);
    }

    return _data;
  }

  final Map<String, String>? _headers;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  final Map<String, String>? _env;

  /// An immutable dictionary containing environment information passed from the server.
  /// This is where information such as CGI/WSGI/Rack keys go that are not HTTP headers.
  Map<String, String> get env => Map.unmodifiable(_env ?? const {});

  final Map<String, String>? _other;

  Map<String, String> get other => Map.unmodifiable(_other ?? const {});

  SentryRequest({
    this.url,
    this.method,
    this.queryString,
    this.cookies,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    Map<String, String>? other,
  })  : _data = data,
        _headers = headers != null ? Map.from(headers) : null,
        _env = env != null ? Map.from(env) : null,
        _other = other != null ? Map.from(other) : null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (url != null) {
      json['url'] = url;
    }

    if (method != null) {
      json['method'] = method;
    }

    if (queryString != null) {
      json['query_string'] = queryString;
    }

    if (_data != null) {
      json['data'] = _data;
    }

    if (cookies != null) {
      json['cookies'] = cookies;
    }

    if (headers.isNotEmpty) {
      json['headers'] = headers;
    }

    if (env.isNotEmpty) {
      json['env'] = env;
    }

    if (other.isNotEmpty) {
      json['other'] = other;
    }

    return json;
  }

  SentryRequest copyWith({
    String? url,
    String? method,
    String? queryString,
    String? cookies,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    Map<String, String>? other,
  }) =>
      SentryRequest(
        url: url ?? this.url,
        method: method ?? this.method,
        queryString: queryString ?? this.queryString,
        cookies: cookies ?? this.cookies,
        data: data ?? _data,
        headers: headers ?? _headers,
        env: env ?? _env,
        other: other ?? _other,
      );
}
