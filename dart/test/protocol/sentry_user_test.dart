import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryUser = SentryUser(
    id: 'id',
    username: 'username',
    email: 'email',
    ipAddress: 'ipAddress',
    data: {'key': 'value'},
    unknown: testUnknown,
  );

  final sentryUserJson = <String, dynamic>{
    'id': 'id',
    'username': 'username',
    'email': 'email',
    'ip_address': 'ipAddress',
    'data': {'key': 'value'},
  };
  sentryUserJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryUser.toJson();

      print("$json");

      expect(
        DeepCollectionEquality().equals(sentryUserJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryUser = SentryUser.fromJson(sentryUserJson);
      final json = sentryUser.toJson();

      expect(
        DeepCollectionEquality().equals(sentryUserJson, json),
        true,
      );
    });

    test('toJson only serialises non-null values', () {
      var data = SentryUser(id: 'id');

      var json = data.toJson();

      expect(json.containsKey('id'), true);
      expect(json.containsKey('username'), false);
      expect(json.containsKey('email'), false);
      expect(json.containsKey('ip_address'), false);
      expect(json.containsKey('extras'), false);

      data = SentryUser(ipAddress: 'ip');

      json = data.toJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('username'), false);
      expect(json.containsKey('email'), false);
      expect(json.containsKey('ip_address'), true);
      expect(json.containsKey('extras'), false);
    });
  });
}
