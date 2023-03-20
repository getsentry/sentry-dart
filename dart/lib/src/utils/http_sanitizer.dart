import '../protocol.dart';
import 'url_details.dart';

class HttpSanitizer {
  static final RegExp _authRegExp = RegExp("(.+://)(.*@)(.*)");
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
      final uri = Uri.parse(url);
      final urlWithAuthRemoved = _urlWithAuthRemoved(uri._url());
      return UrlDetails(
          url: urlWithAuthRemoved.isEmpty ? null : urlWithAuthRemoved,
          query: uri.query.isEmpty ? null : uri.query,
          fragment: uri.fragment.isEmpty ? null : uri.fragment);
    }
  }

  static Map<String, String>? sanitizedHeaders(Map<String, String>? headers) {
    if (headers == null) {
      return null;
    }
    var sanitizedHeaders = <String, String>{};
    headers.forEach((key, value) {
      if (!_securityHeaders.contains(key.toUpperCase())) {
        sanitizedHeaders[key] = value;
      }
    });
    return sanitizedHeaders;
  }

  static String _urlWithAuthRemoved(String url) {
    final userInfoMatch = _authRegExp.firstMatch(url);
    if (userInfoMatch != null && userInfoMatch.groupCount == 3) {
      final userInfoString = userInfoMatch.group(2) ?? '';
      final replacementString = userInfoString.contains(":")
          ? "[Filtered]:[Filtered]@"
          : "[Filtered]@";
      return '${userInfoMatch.group(1) ?? ''}$replacementString${userInfoMatch.group(3) ?? ''}';
    } else {
      return url;
    }
  }
}

extension UriPath on Uri {
  String _url() {
    var buffer = '';
    if (scheme.isNotEmpty) {
      buffer += '$scheme://';
    }
    if (userInfo.isNotEmpty) {
      buffer += '$userInfo@';
    }
    buffer += host;
    if (path.isNotEmpty) {
      buffer += path;
    }
    return buffer;
  }
}

extension SanitizedSentryRequest on SentryRequest {
  SentryRequest sanitized() {
    final urlDetails = HttpSanitizer.sanitizeUrl(url) ?? UrlDetails();
    return copyWith(
      url: urlDetails.urlOrFallback,
      queryString: urlDetails.query,
      fragment: urlDetails.fragment,
      headers: HttpSanitizer.sanitizedHeaders(headers),
    );
  }
}
