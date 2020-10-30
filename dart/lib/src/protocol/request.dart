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
  final dynamic data;

  /// The cookie values as string.
  final String cookies;

  /// A dictionary of submitted headers.
  /// If a header appears multiple times it,
  /// needs to be merged according to the HTTP standard for header merging.
  /// Header names are treated case-insensitively by Sentry.
  final Map<String, String> headers;

  /// A dictionary containing environment information passed from the server.
  /// This is where information such as CGI/WSGI/Rack keys go that are not HTTP headers.
  final Map<String, String> env;

  final Map<String, String> other;

  Request({
    this.url,
    this.method,
    this.queryString,
    this.data,
    this.cookies,
    this.headers,
    this.env,
    this.other,
  });

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
}
