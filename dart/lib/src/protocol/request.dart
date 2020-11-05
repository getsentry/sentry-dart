class Request {
  ///The URL of the request if available.
  ///The query string can be declared either as part of the url,
  ///or separately in queryString.
  final String url;

  ///The HTTP method of the request.
  final String method;

  /// The query string component of the URL.
  ///
  /// If the query string is not declared and part of the url parameter,
  /// Sentry moves it to the query string.
  final String queryString;

  /// Submitted data in a format that makes the most sense.
  /// SDKs should discard large bodies by default.
  /// Can be given as string or structural data of any format.
  final dynamic _data;
  dynamic get data => _data;

  /// The cookie values as string.
  final String cookies;

  final Map<String, String> _headers;

  /// A dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  Map<String, String> get headers => Map.unmodifiable(_headers);

  final Map<String, String> _env;

  /// A dictionary containing environment information passed from the server.
  /// This is where information such as CGI/WSGI/Rack keys go that are not HTTP headers.
  Map<String, String> get env => Map.unmodifiable(_env);

  Map<String, String> get other => Map.unmodifiable(_other);
  final Map<String, String> _other;

  const Request({
    this.url,
    this.method,
    this.queryString,
    this.cookies,
    dynamic data,
    Map<String, String> headers,
    Map<String, String> env,
    Map<String, String> other,
  })  : _data = data,
        _headers = headers,
        _env = env,
        _other = other;

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

    if (data != null) {
      json['data'] = data;
    }

    if (cookies != null) {
      json['cookies'] = cookies;
    }

    if (headers != null && headers.isNotEmpty) {
      json['headers'] = headers;
    }

    if (env != null && env.isNotEmpty) {
      json['env'] = env;
    }

    if (other != null && other.isNotEmpty) {
      json['other'] = other;
    }

    return json;
  }

  Request copyWith({
    String url,
    String method,
    String queryString,
    String cookies,
    dynamic data,
    Map<String, String> headers,
    Map<String, String> env,
    Map<String, String> other,
  }) =>
      Request(
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
