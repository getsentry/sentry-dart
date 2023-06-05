import 'package:meta/meta.dart';

/// Helper to extract header data
@internal
class HttpHeaderUtils {
  /// Get `Content-Length` header
  static int? getContentLength(Map<String, List<String>> headers) {
    final contentLengthHeader =
        headers['content-length'] ?? headers['Content-Length'];
    if (contentLengthHeader != null && contentLengthHeader.isNotEmpty) {
      final headerValue = contentLengthHeader.first;
      return int.tryParse(headerValue);
    }
    return null;
  }
}
