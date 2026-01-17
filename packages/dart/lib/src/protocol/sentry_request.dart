import 'package:meta/meta.dart';

import '../utils/http_sanitizer.dart';
import '../utils/iterable_utils.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// The Request interface contains information on a HTTP request related to the event.
/// In client SDKs, this can be an outgoing request, or the request that rendered the current web page.
/// On server SDKs, this could be the incoming web request that is being handled.
class SentryRequest {
  ///The URL of the request if available.
  ///The query string can be declared either as part of the url,
  ///or separately in queryString.
  String? url;

  ///The HTTP method of the request.
  String? method;

  /// The query string component of the URL.
  ///
  /// If the query string is not declared and part of the url parameter,
  /// Sentry moves it to the query string.
  String? queryString;

  /// The cookie values as string.
  String? cookies;

  dynamic _data;

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

  Map<String, String>? _headers;

  /// An immutable dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers ?? const {});

  set headers(Map<String, String> headers) {
    _headers = Map<String, String>.of(headers);
  }

  Map<String, String>? _env;

  /// An immutable dictionary containing environment information passed from the server.
  /// This is where information such as CGI/WSGI/Rack keys go that are not HTTP headers.
  Map<String, String> get env => Map.unmodifiable(_env ?? const {});

  /// The fragment of the request URL.
  String? fragment;

  /// The API target/specification that made the request.
  /// Values can be `graphql`, `rest`, etc.
  ///
  /// The data field should contain the request and response bodies based on
  /// its target specification.
  String? apiTarget;

  @internal
  final Map<String, dynamic>? unknown;

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
    this.unknown,
  })  : _data = data,
        _headers = headers != null ? Map.from(headers) : null,
        // Look for a 'Set-Cookie' header (case insensitive) if not given.
        cookies = cookies ??
            IterableUtils.firstWhereOrNull(
              headers?.entries,
              (MapEntry<String, String> e) => e.key.toLowerCase() == 'cookie',
            )?.value,
        _env = env != null ? Map.from(env) : null;

  factory SentryRequest.fromUri({
    required Uri uri,
    String? method,
    String? cookies,
    dynamic data,
    Map<String, String>? headers,
    Map<String, String>? env,
    String? apiTarget,
  }) {
    final request = SentryRequest(
      url: uri.toString(),
      method: method,
      cookies: cookies,
      data: data,
      headers: headers,
      env: env,
      queryString: uri.query,
      fragment: uri.fragment,
      // ignore: deprecated_member_use_from_same_package
      apiTarget: apiTarget,
    );
    request.sanitize();
    return request;
  }

  /// Deserializes a [SentryRequest] from JSON [Map].
  factory SentryRequest.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final headersJson = json.getValueOrNull<Map<String, dynamic>>('headers');
    final envJson = json.getValueOrNull<Map<String, dynamic>>('env');
    return SentryRequest(
      url: json.getValueOrNull('url'),
      method: json.getValueOrNull('method'),
      queryString: json.getValueOrNull('query_string'),
      cookies: json.getValueOrNull('cookies'),
      data: json.getValueOrNull('data'),
      headers:
          headersJson == null ? null : Map<String, String>.from(headersJson),
      env: envJson == null ? null : Map<String, String>.from(envJson),
      fragment: json.getValueOrNull('fragment'),
      apiTarget: json.getValueOrNull('api_target'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (queryString != null) 'query_string': queryString,
      if (_data != null) 'data': _data,
      if (cookies != null) 'cookies': cookies,
      if (headers.isNotEmpty) 'headers': headers,
      if (env.isNotEmpty) 'env': env,
      if (fragment != null) 'fragment': fragment,
      if (apiTarget != null) 'api_target': apiTarget,
    };
  }

  @Deprecated('Assign values directly to the instance.')
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
        unknown: unknown,
      );
}
