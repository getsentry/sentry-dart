import '../protocol.dart';

Map<String, String> buildHeaders(/*String authHeader, */ {Sdk sdk}) {
  final headers = {'Content-Type': 'application/json'};

  return headers;
}
