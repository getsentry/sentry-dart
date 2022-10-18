import 'dart:io';

/// Encodes the body using Gzip compression
// ignore: unused-code
List<int> compressBody(List<int> body, Map<String, String> headers) {
  headers['Content-Encoding'] = 'gzip';
  return gzip.encode(body);
}

/// Encodes bytes in sink using Gzip compression
// ignore: unused-code
Sink<List<int>> compressInSink(
    Sink<List<int>> sink, Map<String, String> headers) {
  headers['Content-Encoding'] = 'gzip';
  return GZipCodec().encoder.startChunkedConversion(sink);
}
