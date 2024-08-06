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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryRequest;

      final copy = data.copyWith();

      expect(
        DeepCollectionEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryRequest;

      final copy = data.copyWith(
        url: 'url1',
        method: 'method1',
        queryString: 'queryString1',
        cookies: 'cookies1',
        data: {'key1': 'value1'},
      );

      expect('url1', copy.url);
      expect('method1', copy.method);
      expect('queryString1', copy.queryString);
      expect('cookies1', copy.cookies);
      expect({'key1': 'value1'}, copy.data);
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
