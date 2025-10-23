import 'package:meta/meta.dart';
import '../sentry.dart';
import '../protocol/sentry_level.dart';

/// Extension providing type-safe value extraction from JSON maps
@internal
extension TypeSafeMapExtension on Map<String, dynamic> {
  /// Type-safe string extraction
  String? getString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;

    _logTypeMismatch(key, 'String', value.runtimeType.toString());
    return null;
  }

  /// Type-safe int extraction with num support
  int? getInt(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    _logTypeMismatch(key, 'int', value.runtimeType.toString());
    return null;
  }

  /// Type-safe double extraction with num support
  double? getDouble(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();

    _logTypeMismatch(key, 'double', value.runtimeType.toString());
    return null;
  }

  /// Type-safe bool extraction
  bool? getBool(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is bool) return value;

    _logTypeMismatch(key, 'bool', value.runtimeType.toString());
    return null;
  }

  /// Type-safe DateTime extraction from string
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is! String) {
      _logTypeMismatch(
          key, 'String (for DateTime)', value.runtimeType.toString());
      return null;
    }

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) {
      _logParseError(key, 'DateTime', value);
    }
    return dateTime;
  }

  void _logTypeMismatch(String key, String expected, String actual) {
    Sentry.currentHub.options.log(
      SentryLevel.warning,
      'Type mismatch in JSON deserialization: key "$key" expected $expected but got $actual',
    );
  }

  void _logParseError(String key, String expected, dynamic value) {
    Sentry.currentHub.options.log(
      SentryLevel.warning,
      'Parse error in JSON deserialization: key "$key" could not be parsed as $expected from value "$value"',
    );
  }
}
