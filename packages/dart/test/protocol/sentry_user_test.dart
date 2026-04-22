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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryUser;

      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = sentryUser;
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith(
        id: 'id1',
        username: 'username1',
        email: 'email1',
        ipAddress: 'ipAddress1',
        data: {'key1': 'value1'},
      );

      expect('id1', copy.id);
      expect('username1', copy.username);
      expect('email1', copy.email);
      expect('ipAddress1', copy.ipAddress);
      expect({'key1': 'value1'}, copy.data);
    });
  });

  group('toAttributes', () {
    test('returns empty map when id, name, email, and ipAddress are all null',
        () {
      expect(SentryUser(username: 'ada').toAttributes(), isEmpty);
    });

    test(
        'maps id, name, email, and ipAddress to stable semantic attribute keys',
        () {
      final user = SentryUser(
        id: 'user-123',
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        ipAddress: '127.0.0.1',
      );

      final attributes = user.toAttributes();

      expect(attributes[SemanticAttributesConstants.userId]?.value, 'user-123');
      expect(attributes[SemanticAttributesConstants.userId]?.type, 'string');
      expect(attributes[SemanticAttributesConstants.userName]?.value,
          'Ada Lovelace');
      expect(attributes[SemanticAttributesConstants.userEmail]?.value,
          'ada@example.com');
      expect(attributes[SemanticAttributesConstants.userIpAddress]?.value,
          '127.0.0.1');
    });

    test('maps populated geo fields to stable user.geo.* keys', () {
      final user = SentryUser(
        id: 'user-123',
        geo: SentryGeo(
          city: 'Vienna',
          countryCode: 'AT',
          region: 'Vienna',
          subregion: 'Europe',
          subdivision: 'Wien',
        ),
      );

      final attributes = user.toAttributes();

      expect(
          attributes[SemanticAttributesConstants.userGeoCity]?.value, 'Vienna');
      expect(attributes[SemanticAttributesConstants.userGeoCountryCode]?.value,
          'AT');
      expect(attributes[SemanticAttributesConstants.userGeoRegion]?.value,
          'Vienna');
      expect(attributes[SemanticAttributesConstants.userGeoSubregion]?.value,
          'Europe');
      expect(attributes[SemanticAttributesConstants.userGeoSubdivision]?.value,
          'Wien');
    });

    test('omits geo attributes when geo is null', () {
      final user = SentryUser(id: 'user-123');

      final attributes = user.toAttributes();

      expect(attributes.containsKey(SemanticAttributesConstants.userGeoCity),
          false);
      expect(
          attributes
              .containsKey(SemanticAttributesConstants.userGeoCountryCode),
          false);
    });

    test('omits fields without a stable semantic key', () {
      final user = SentryUser(
        id: 'user-123',
        username: 'adalovelace',
      );

      final attributes = user.toAttributes();

      expect(attributes.keys,
          unorderedEquals([SemanticAttributesConstants.userId]));
    });
  });
}
