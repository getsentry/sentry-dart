import 'package:meta/meta.dart';

import '../utils/http_sanitizer.dart';
import '../utils/iterable_utils.dart';
import 'access_aware_map.dart';

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
    this._data,
    Map<String, String>? headers,
    Map<String, String>? env,
    this.unknown,
  }) : _headers = headers != null ? Map.from(headers) : null,
       // Look for a 'Set-Cookie' header (case insensitive) if not given.
       cookies =
           cookies ??
           headers?.entries
               .firstWhereOrNull((e) => e.key.toLowerCase() == 'cookie')
               ?.value,
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
  factory SentryRequest.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryRequest(
      url: json.readString('url'),
      method: json.readString('method'),
      queryString: json.readString('query_string'),
      cookies: json.readString('cookies'),
      data: json['data'],
      headers: json.readStringMap('headers'),
      env: json.readStringMap('env'),
      fragment: json.readString('fragment'),
      apiTarget: json.readString('api_target'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'url': ?url,
      'method': ?method,
      'query_string': ?queryString,
      'data': ?_data,
      'cookies': ?cookies,
      if (headers.isNotEmpty) 'headers': headers,
      if (env.isNotEmpty) 'env': env,
      'fragment': ?fragment,
      'api_target': ?apiTarget,
    };
  }
}
