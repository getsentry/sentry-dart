import 'access_aware_map.dart';

/// Geographical location of the end user or device.
class SentryGeo {
  SentryGeo({
    this.city,
    this.countryCode,
    this.region,
    this.subregion,
    this.subdivision,
  });

  factory SentryGeo.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryGeo(
      city: json.readString('city'),
      countryCode: json.readString('country_code'),
      region: json.readString('region'),
      subregion: json.readString('subregion'),
      subdivision: json.readString('subdivision'),
    );
  }

  /// Human readable city name.
  final String? city;

  /// Two-letter country code (ISO 3166-1 alpha-2).
  final String? countryCode;

  /// Human readable region name or code.
  final String? region;

  /// Subregion (e.g. a continental area).
  final String? subregion;

  /// Subdivision (e.g. state, province).
  final String? subdivision;

  Map<String, dynamic> toJson() {
    return {
      'city': ?city,
      'country_code': ?countryCode,
      'region': ?region,
      'subregion': ?subregion,
      'subdivision': ?subdivision,
    };
  }
}
