import 'dart:io';

/// Encodes the body using Gzip compression
void compressBody(List<int> body, Map<String, String> headers) {
  headers['Content-Encoding'] = 'gzip';
  body = gzip.encode(body);
}
