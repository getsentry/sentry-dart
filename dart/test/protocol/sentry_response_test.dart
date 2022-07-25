import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final sentryResponse = SentryResponse(
    url: 'url',
    body: 'foobar',
    redirected: true,
    status: 'OK',
    statusCode: 200,
    headers: {'header_key': 'header_value'},
    other: {'other_key': 'other_value'},
  );

  final sentryResponseJson = <String, dynamic>{
    'url': 'url',
    'body': 'foobar',
    'redirected': true,
    'status': 'OK',
    'status_code': 200,
    'headers': {'header_key': 'header_value'},
    'other': {'other_key': 'other_value'},
  };

  group('json', () {
    test('toJson', () {
      final json = sentryResponse.toJson();

      expect(
        DeepCollectionEquality().equals(sentryResponseJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryResponse = SentryResponse.fromJson(sentryResponseJson);
      final json = sentryResponse.toJson();

      expect(
        DeepCollectionEquality().equals(sentryResponseJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryResponse;

      final copy = data.copyWith();

      expect(
        DeepCollectionEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryResponse;

      final copy = data.copyWith(
        url: 'url1',
        body: 'barfoo',
        headers: {'key1': 'value1'},
        redirected: false,
        statusCode: 301,
        status: 'REDIRECT',
      );

      expect('url1', copy.url);
      expect('barfoo', copy.body);
      expect({'key1': 'value1'}, copy.headers);
      expect(false, copy.redirected);
      expect(301, copy.statusCode);
      expect('REDIRECT', copy.status);
    });
  });
}
