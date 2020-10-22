import '../protocol.dart';

Map<String, String> buildHeaders(String authHeader, {Sdk sdk}) {
  final headers = {
    'Content-Type': 'application/json',
  };

  if (authHeader != null) {
    headers['X-Sentry-Auth'] = authHeader;
  }

  // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
  // for web it use browser user agent
  headers['User-Agent'] = sdk.identifier;

  return headers;
}
