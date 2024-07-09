import 'package:meta/meta.dart';

@internal
Map<String, dynamic>? unknownFrom(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) {
  Map<String, dynamic> unknown = json.keys
      .where((key) => !knownKeys.contains(key))
      .fold<Map<String, dynamic>>({}, (map, key) {
    map[key] = json[key];
    return map;
  });
  return unknown.isNotEmpty ? unknown : null;
}
