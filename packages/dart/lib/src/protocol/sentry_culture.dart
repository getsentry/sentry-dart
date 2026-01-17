import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// Culture Context describes certain properties of the culture in which the
/// software is used.
class SentryCulture {
  static const type = 'culture';

  SentryCulture({
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
      calendar: json.getValueOrNull('calendar'),
      displayName: json.getValueOrNull('display_name'),
      locale: json.getValueOrNull('locale'),
      is24HourFormat: json.getValueOrNull('is_24_hour_format'),
      timezone: json.getValueOrNull('timezone'),
      unknown: json.notAccessed(),
    );
  }

  /// Optional: For example `GregorianCalendar`. Free form string.
  String? calendar;

  /// Optional: Human readable name of the culture.
  /// For example `English (United States)`
  String? displayName;

  /// Optional. The name identifier, usually following the RFC 4646.
  /// For example `en-US` or `pt-BR`.
  String? locale;

  /// Optional. boolean, either true or false.
  bool? is24HourFormat;

  /// Optional. The timezone of the locale. For example, `Europe/Vienna`.
  String? timezone;

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

  @Deprecated('Will be removed in a future version.')
  SentryCulture clone() => SentryCulture(
        calendar: calendar,
        displayName: displayName,
        locale: locale,
        is24HourFormat: is24HourFormat,
        timezone: timezone,
        unknown: unknown,
      );

  @Deprecated('Assign values directly to the instance.')
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
