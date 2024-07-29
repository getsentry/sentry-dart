import 'package:meta/meta.dart';

import 'access_aware_map.dart';

/// Culture Context describes certain properties of the culture in which the
/// software is used.
@immutable
class SentryCulture {
  static const type = 'culture';

  const SentryCulture({
    this.calendar,
    this.displayName,
    this.locale,
    this.is24HourFormat,
    this.timezone,
    this.unknown,
  });

  factory SentryCulture.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryCulture(
      calendar: json['calendar'],
      displayName: json['display_name'],
      locale: json['locale'],
      is24HourFormat: json['is_24_hour_format'],
      timezone: json['timezone'],
      unknown: json.notAccessed(),
    );
  }

  /// Optional: For example `GregorianCalendar`. Free form string.
  final String? calendar;

  /// Optional: Human readable name of the culture.
  /// For example `English (United States)`
  final String? displayName;

  /// Optional. The name identifier, usually following the RFC 4646.
  /// For example `en-US` or `pt-BR`.
  final String? locale;

  /// Optional. boolean, either true or false.
  final bool? is24HourFormat;

  /// Optional. The timezone of the locale. For example, `Europe/Vienna`.
  final String? timezone;

  @internal
  final Map<String, dynamic>? unknown;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (calendar != null) 'calendar': calendar!,
      if (displayName != null) 'display_name': displayName!,
      if (locale != null) 'locale': locale!,
      if (is24HourFormat != null) 'is_24_hour_format': is24HourFormat!,
      if (timezone != null) 'timezone': timezone!,
    };
  }

  SentryCulture clone() => SentryCulture(
        calendar: calendar,
        displayName: displayName,
        locale: locale,
        is24HourFormat: is24HourFormat,
        timezone: timezone,
        unknown: unknown,
      );

  SentryCulture copyWith({
    String? calendar,
    String? displayName,
    String? locale,
    bool? is24HourFormat,
    String? timezone,
  }) =>
      SentryCulture(
        calendar: calendar ?? this.calendar,
        displayName: displayName ?? this.displayName,
        locale: locale ?? this.locale,
        is24HourFormat: is24HourFormat ?? this.is24HourFormat,
        timezone: timezone ?? this.timezone,
        unknown: unknown,
      );
}
