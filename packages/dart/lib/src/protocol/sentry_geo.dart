/// Geographical location of the end user or device.
class SentryGeo {
  SentryGeo({this.city, this.countryCode, this.region});

  factory SentryGeo.fromJson(Map<String, dynamic> json) {
    return SentryGeo(
      city: json['city'],
      countryCode: json['country_code'],
      region: json['region'],
    );
  }

  /// Human readable city name.
  final String? city;

  /// Two-letter country code (ISO 3166-1 alpha-2).
  final String? countryCode;

  /// Human readable region name or code.
  final String? region;

  Map<String, dynamic> toJson() {
    return {
      if (city != null) 'city': city,
      if (countryCode != null) 'country_code': countryCode,
      if (region != null) 'region': region,
    };
  }
}
