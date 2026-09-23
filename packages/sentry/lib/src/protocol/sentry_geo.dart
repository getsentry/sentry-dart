/// Geographical location of the end user or device.
class SentryGeo {
  SentryGeo({
    this.city,
    this.countryCode,
    this.region,
    this.subregion,
    this.subdivision,
  });

  factory SentryGeo.fromJson(Map<String, dynamic> json) {
    return SentryGeo(
      city: json['city'],
      countryCode: json['country_code'],
      region: json['region'],
      subregion: json['subregion'],
      subdivision: json['subdivision'],
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
      if (city != null) 'city': city,
      if (countryCode != null) 'country_code': countryCode,
      if (region != null) 'region': region,
      if (subregion != null) 'subregion': subregion,
      if (subdivision != null) 'subdivision': subdivision,
    };
  }
}
