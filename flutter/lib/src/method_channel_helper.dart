import 'package:meta/meta.dart';

/// Makes sure no invalid data is sent over method channels.
@internal
class MethodChannelHelper {
  static Map<String, dynamic>? normalizeMap(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final mapToReturn = <String, dynamic>{};
    data.forEach((key, value) {
      if (_isPrimitive(value)) {
        mapToReturn[key] = value;
      } else if (value is List<dynamic>) {
        mapToReturn[key] = _normalizeList(value);
      } else if (value is Map<String, dynamic>) {
        mapToReturn[key] = normalizeMap(value);
      } else {
        mapToReturn[key] = value.toString();
      }
    });
    return mapToReturn;
  }

  static List<dynamic> _normalizeList(List<dynamic> data) {
    final listToReturn = <dynamic>[];
    for (var element in data) {
      if (_isPrimitive(element)) {
        listToReturn.add(element);
      } else if (element is List<dynamic>) {
        listToReturn.add(_normalizeList(element));
      } else if (element is Map<String, dynamic>) {
        listToReturn.add(normalizeMap(element));
      } else {
        listToReturn.add(element.toString());
      }
    }
    return listToReturn;
  }

  static bool _isPrimitive(dynamic value) {
    return value == null || value is String || value is num || value is bool;
  }
}
