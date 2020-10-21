import 'dart:convert';
import 'dart:io';

List<int> bodyEncoder(
  Map<String, dynamic> data,
  Map<String, String> headers, {
  bool compressPayload,
}) {
  // [SentryIOClient] implement gzip compression
  // gzip compression is not available on browser
  var body = utf8.encode(json.encode(data));
  if (compressPayload) {
    headers['Content-Encoding'] = 'gzip';
    body = gzip.encode(body);
  }
  return body;
}
