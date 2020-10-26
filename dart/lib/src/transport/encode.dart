import 'dart:io';

/// Encodes the body using Gzip compression
List<int> compressBody(List<int> body, Map<String, String> headers) {
  headers['Content-Encoding'] = 'gzip';
  return gzip.encode(body);
}
