import 'package:meta/meta.dart';

import 'url_details.dart';

@internal
class UrlUtils {
  static final RegExp authRegExp = RegExp("(.+://)(.*@)(.*)");

  static UrlDetails? parse(String? url) {
    if (url == null) {
      return null;
    }

    final queryIndex = url.indexOf('?');
    final fragmentIndex = url.indexOf('#');

    if (queryIndex > -1 && fragmentIndex > -1 && fragmentIndex < queryIndex) {
      // url considered malformed because it has fragment
      return UrlDetails(null, null, null);
    } else {
      final uri = Uri.parse(url);
      final urlWithAuthRemoved = _urlWithAuthRemoved(uri._url());
      return UrlDetails(
          urlWithAuthRemoved.isEmpty ? null : urlWithAuthRemoved,
          uri.query.isEmpty ? null : uri.query,
          uri.fragment.isEmpty ? null : uri.fragment);
    }
  }

  static String _urlWithAuthRemoved(String url) {
    final userInfoMatch = authRegExp.firstMatch(url);
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
