import 'package:meta/meta.dart';

import '../protocol.dart';
import 'url_details.dart';

@internal
class HttpSanitizer {
  static final List<String> _securityHeaders = [
    "X-FORWARDED-FOR",
    "AUTHORIZATION",
    "COOKIE",
    "SET-COOKIE",
    "X-API-KEY",
    "X-REAL-IP",
    "REMOTE-ADDR",
    "FORWARDED",
    "PROXY-AUTHORIZATION",
    "X-CSRF-TOKEN",
    "X-CSRFTOKEN",
    "X-XSRF-TOKEN"
  ];

  /// Parse and sanitize url data for sentry.io
  static UrlDetails? sanitizeUrl(String? url) {
    if (url == null) {
      return null;
    }

    final queryIndex = url.indexOf('?');
    final fragmentIndex = url.indexOf('#');

    if (queryIndex > -1 && fragmentIndex > -1 && fragmentIndex < queryIndex) {
      // url considered malformed because of fragment position
      return UrlDetails();
    } else {
      try {
        final uri = Uri.parse(url);
        final urlWithRedactedAuth = uri._urlWithRedactedAuth();
        return UrlDetails(
            url: urlWithRedactedAuth.isEmpty ? null : urlWithRedactedAuth,
            query: uri.query.isEmpty ? null : uri.query,
            fragment: uri.fragment.isEmpty ? null : uri.fragment);
      } catch (_) {
        return null;
      }
    }
  }

  static Map<String, String>? sanitizedHeaders(Map<String, String>? headers) {
    if (headers == null) {
      return null;
    }
    final sanitizedHeaders = <String, String>{};
    headers.forEach((key, value) {
      if (!_securityHeaders.contains(key.toUpperCase())) {
        sanitizedHeaders[key] = value;
      }
    });
    return sanitizedHeaders;
  }
}

extension _UriPath on Uri {
  String _urlWithRedactedAuth() {
    var buffer = '';
    if (scheme.isNotEmpty) {
      buffer += '$scheme://';
    }
    if (userInfo.isNotEmpty) {
      buffer +=
          userInfo.contains(":") ? "[Filtered]:[Filtered]@" : "[Filtered]@";
    }
    buffer += host;
    if (path.isNotEmpty) {
      buffer += path;
    }
    return buffer;
  }
}

@internal
extension SanitizedSentryRequest on SentryRequest {
  SentryRequest sanitized() {
    final urlDetails = HttpSanitizer.sanitizeUrl(url) ?? UrlDetails();
    return copyWith(
      url: urlDetails.urlOrFallback,
      queryString: urlDetails.query,
      fragment: urlDetails.fragment,
      headers: HttpSanitizer.sanitizedHeaders(headers),
      removeCookies: true,
    );
  }
}
