import '../protocol.dart';

Map<String, String> buildHeaders(String authHeader, {Sdk sdk}) {
  final headers = {
    'Content-Type': 'application/json',
  };

  if (authHeader != null) {
    headers['X-Sentry-Auth'] = authHeader;
  }

  return headers;
}
