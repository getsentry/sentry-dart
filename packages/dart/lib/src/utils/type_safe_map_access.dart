import 'package:meta/meta.dart';
import '../debug_logger.dart';

/// Extension providing type-safe value extraction from JSON maps
@internal
extension TypeSafeMapExtension on Map<String, dynamic> {
  /// Generic, type-safe extraction with a few built-in coercions:
  /// - num -> int
  /// - num -> double
  /// - 0/1 -> bool
  /// - String (ISO) -> DateTime
  T? getValueOrNull<T>(String key) {
    final value = this[key];
    if (value == null) return null;

    final convertedValue = _tryConvertValue<T>(key, value);
    if (convertedValue != null) return convertedValue;

    _logTypeMismatch(key, _expectedTypeFor<T>(), value.runtimeType.toString());
    return null;
  }

  T? _tryConvertValue<T>(String key, Object value) {
    // Direct hit.
    if (value is T) return value as T;

    // num -> int
    if (T == int) {
      if (value is num) return value.toInt() as T;
      return null;
    }

    // num -> double
    if (T == double) {
      if (value is num) return value.toDouble() as T;
      return null;
    }

    // 0/1 -> bool
    if (T == bool) {
      // if value is bool directly already handled above
      if (value is num) {
        if (value == 0) return false as T;
        if (value == 1) return true as T;
      }
      return null;
    }

    // String(ISO8601) -> DateTime
    if (T == DateTime) {
      if (value is! String) {
        _logTypeMismatch(
            key, 'String (for DateTime)', value.runtimeType.toString());
        return null;
      }
      final dt = DateTime.tryParse(value);
      if (dt == null) {
        _logParseError(key, 'DateTime', value);
        return null;
      }
      return dt as T;
    }

    return null;
  }

  String _expectedTypeFor<T>() {
    if (T == DateTime) {
      return 'String (for DateTime)';
    }
    return T.toString();
  }

  void _logTypeMismatch(String key, String expected, String actual) {
    debugLogger.warning(
      'Type mismatch in JSON deserialization: key "$key" expected $expected but got $actual',
      category: 'json',
    );
  }

  void _logParseError(String key, String expected, Object value) {
    debugLogger.warning(
      'Parse error in JSON deserialization: key "$key" could not be parsed as $expected from value "$value"',
      category: 'json',
    );
  }
}
