import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('SentryGeo', () {
    test('serializes to json', () {
      final json = fixture.sentryGeo.toJson();

      expect(
        MapEquality().equals(fixture.sentryGeoJson, json),
        true,
      );
    });

    test('deserializes from json', () {
      final sentryGeo = SentryGeo.fromJson(fixture.sentryGeoJson);
      final json = sentryGeo.toJson();

      expect(
        MapEquality().equals(fixture.sentryGeoJson, json),
        true,
      );
    });
  });
}

class Fixture {
  final sentryGeo = SentryGeo(
    city: 'fixture-city',
    countryCode: 'fixture-country',
    region: 'fixture-region',
  );

  final sentryGeoJson = <String, dynamic>{
    'city': 'fixture-city',
    'country_code': 'fixture-country',
    'region': 'fixture-region',
  };
}
