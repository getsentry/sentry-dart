import 'package:meta/meta.dart';

/// Normalizes data for serialization across native boundaries.
/// Converts non-primitive types to strings for safe serialization.
@internal
dynamic normalize(dynamic data) {
  if (data == null) return null;
  if (_isPrimitive(data)) return data;
  if (data is List<dynamic>) return _normalizeList(data);
  if (data is Map<String, dynamic>) return normalizeMap(data);
  return data.toString();
}

@internal
Map<String, dynamic>? normalizeMap(Map<String, dynamic>? data) {
  if (data == null) return null;
  return data.map((key, value) => MapEntry(key, normalize(value)));
}

List<dynamic>? _normalizeList(List<dynamic>? data) {
  if (data == null) return null;
  return data.map((e) => normalize(e)).toList();
}

bool _isPrimitive(dynamic value) {
  return value == null || value is String || value is num || value is bool;
}
