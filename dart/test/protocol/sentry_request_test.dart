import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryRequest = SentryRequest(
    url: 'url',
    method: 'method',
    queryString: 'queryString',
    cookies: 'cookies',
    data: {'key': 'value'},
    headers: {'header_key': 'header_value'},
    env: {'env_key': 'env_value'},
    apiTarget: 'GraphQL',
    // ignore: deprecated_member_use_from_same_package
    other: {'other_key': 'other_value'},
    unknown: testUnknown,
  );

  final sentryRequestJson = <String, dynamic>{
    'url': 'url',
    'method': 'method',
    'query_string': 'queryString',
    'cookies': 'cookies',
    'data': {'key': 'value'},
    'headers': {'header_key': 'header_value'},
    'env': {'env_key': 'env_value'},
    'api_target': 'GraphQL',
    'other': {'other_key': 'other_value'},
  };
  sentryRequestJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryRequest.toJson();

      expect(
        DeepCollectionEquality().equals(sentryRequestJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryRequest = SentryRequest.fromJson(sentryRequestJson);
      final json = sentryRequest.toJson();

      expect(
        DeepCollectionEquality().equals(sentryRequestJson, json),
        true,
      );
    });
  });

  test('SentryRequest.fromUri', () {
    final request = SentryRequest.fromUri(
      uri: Uri.parse('https://example.org/foo/bar?key=value#fragment'),
    );

    expect(request.url, 'https://example.org/foo/bar');
    expect(request.fragment, 'fragment');
    expect(request.queryString, 'key=value');
  });
}
