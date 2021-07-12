import 'package:meta/meta.dart';

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
  });

  // ignore: strict_raw_type
  factory SentryCulture.fromJson(Map data) => SentryCulture(
        // This class should be deserializable from Map<String, dynamic> and Map<Object?, Object?>,
        // because it comes from json.decode which is a Map<String, dynamic> and from
        // methodchannels which is a Map<Object?, Object?>.
        // Map<String, dynamic> and Map<Object?, Object?> only have
        // Map<dynamic, dynamic> as common type constraint
        calendar: data['calendar'] as String?,
        displayName: data['display_name'] as String?,
        locale: data['locale'] as String?,
        is24HourFormat: data['is_24_hour_format'] as bool?,
        timezone: data['timezone'] as String?,
      );

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

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, Object> toJson() {
    return <String, Object>{
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
      );
}
