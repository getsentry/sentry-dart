import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final sentryResponse = SentryResponse(
    bodySize: 42,
    statusCode: 200,
    headers: {'header_key': 'header_value'},
    cookies: 'foo=bar, another=cookie',
    data: 'foo',
  );

  final sentryResponseJson = <String, dynamic>{
    'body_size': 42,
    'status_code': 200,
    'headers': {'header_key': 'header_value'},
    'cookies': 'foo=bar, another=cookie',
    'data': 'foo',
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
      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = sentryResponse;

      final copy = data.copyWith(
        bodySize: 11,
        headers: {'key1': 'value1'},
        statusCode: 301,
      );

      expect(11, copy.bodySize);
      expect({'key1': 'value1'}, copy.headers);
      expect(301, copy.statusCode);
    });
  });
}
