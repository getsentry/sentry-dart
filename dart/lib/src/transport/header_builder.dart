import '../protocol.dart';

Map<String, String> buildHeaders(/*String authHeader, */ {Sdk sdk}) {
  final headers = {
    'Content-Type': 'application/json',
    // NOTE(lejard_h) overriding user agent on VM and Flutter not sure why
    // for web it use browser user agent
    'User-Agent': sdk.identifier
  };

  headers['User-Agent'] = sdk.identifier;

  return headers;
}
