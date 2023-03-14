import 'url_details.dart';

class UrlUtils {
  static final RegExp _authRegExp = RegExp("(.+://)(.*@)(.*)");

  /// Parse and prepare url data for sentry.io
  static UrlDetails? parse(String? url) {
    if (url == null) {
      return null;
    }

    final queryIndex = url.indexOf('?');
    final fragmentIndex = url.indexOf('#');

    if (queryIndex > -1 && fragmentIndex > -1 && fragmentIndex < queryIndex) {
      // url considered malformed because it has fragment
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
