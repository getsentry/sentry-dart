import 'package:meta/meta.dart';

/// Makes sure no invalid data is sent over method channels.
@internal
class MethodChannelHelper {
  static dynamic normalize(dynamic data) {
    if (data == null) {
      return null;
    }
    if (_isPrimitive(data)) {
      return data;
    } else if (data is List<dynamic>) {
      return _normalizeList(data);
    } else if (data is Map<String, dynamic>) {
      return normalizeMap(data);
    } else {
      return data.toString();
    }
  }

  static Map<String, dynamic>? normalizeMap(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    return data.map((key, value) => MapEntry(key, normalize(value)));
  }

  static List<dynamic>? _normalizeList(List<dynamic>? data) {
    if (data == null) {
      return null;
    }
    return data.map((e) => normalize(e)).toList();
  }

  static bool _isPrimitive(dynamic value) {
    return value == null || value is String || value is num || value is bool;
  }
}
