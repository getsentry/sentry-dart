import 'package:meta/meta.dart';

import '../utils/iterable_utils.dart';
import '../utils/http_sanitizer.dart';

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

  @Deprecated('Will be removed in v8. Use [data] instead')
  Map<String, String> get other => Map.unmodifiable(_other ?? const {});

  /// The fragment of the request URL.
  final String? fragment;

  /// The API target/specification that made the request.
  /// Values can be `graphql`, `rest`, etc.
  ///
  /// The data field should contain the request and response bodies based on
  /// its target specification.
  final String? apiTarget;

  SentryRequest({
    this.url,
    this.method,
    this.queryString,
    String? cookies,
    this.fragment,
    this.apiTarget,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    @Deprecated('Will be removed in v8. Use [data] instead')
    Map<String, String>? other,
  })  : _data = data,
        _headers = headers != null ? Map.from(headers) : null,
        // Look for a 'Set-Cookie' header (case insensitive) if not given.
        cookies = cookies ??
            IterableUtils.firstWhereOrNull(
              headers?.entries,
              (MapEntry<String, String> e) => e.key.toLowerCase() == 'cookie',
            )?.value,
        _env = env != null ? Map.from(env) : null,
        _other = other != null ? Map.from(other) : null;

  factory SentryRequest.fromUri({
    required Uri uri,
    String? method,
    String? cookies,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    String? apiTarget,
    @Deprecated('Will be removed in v8. Use [data] instead')
    Map<String, String>? other,
  }) {
    return SentryRequest(
      url: uri.toString(),
      method: method,
      cookies: cookies,
      data: data,
      headers: headers,
      env: env,
      queryString: uri.query,
      fragment: uri.fragment,
      // ignore: deprecated_member_use_from_same_package
      other: other,
      apiTarget: apiTarget,
    ).sanitized();
  }

  /// Deserializes a [SentryRequest] from JSON [Map].
  factory SentryRequest.fromJson(Map<String, dynamic> json) {
    return SentryRequest(
      url: json['url'],
      method: json['method'],
      queryString: json['query_string'],
      cookies: json['cookies'],
      data: json['data'],
      headers: json.containsKey('headers') ? Map.from(json['headers']) : null,
      env: json.containsKey('env') ? Map.from(json['env']) : null,
      // ignore: deprecated_member_use_from_same_package
      other: json.containsKey('other') ? Map.from(json['other']) : null,
      fragment: json['fragment'],
      apiTarget: json['api_target'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (queryString != null) 'query_string': queryString,
      if (_data != null) 'data': _data,
      if (cookies != null) 'cookies': cookies,
      if (headers.isNotEmpty) 'headers': headers,
      if (env.isNotEmpty) 'env': env,
      // ignore: deprecated_member_use_from_same_package
      if (other.isNotEmpty) 'other': other,
      if (fragment != null) 'fragment': fragment,
      if (apiTarget != null) 'api_target': apiTarget,
    };
  }

  SentryRequest copyWith({
    String? url,
    String? method,
    String? queryString,
    String? cookies,
    String? fragment,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    bool removeCookies = false,
    String? apiTarget,
    @Deprecated('Will be removed in v8. Use [data] instead')
    Map<String, String>? other,
  }) =>
      SentryRequest(
        url: url ?? this.url,
        method: method ?? this.method,
        queryString: queryString ?? this.queryString,
        cookies: removeCookies ? null : cookies ?? this.cookies,
        data: data ?? _data,
        headers: headers ?? _headers,
        env: env ?? _env,
        fragment: fragment ?? this.fragment,
        apiTarget: apiTarget ?? this.apiTarget,
        // ignore: deprecated_member_use_from_same_package
        other: other ?? _other,
      );
}
