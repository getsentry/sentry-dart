import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

@internal
Map<String, dynamic> decodeUtf8JsonMap(Uint8List bytes) {
  final jsonString = utf8.decode(bytes);
  final decoded = json.decode(jsonString);
  return decoded as Map<String, dynamic>;
}

@internal
List<Map<String, dynamic>> decodeUtf8JsonListOfMaps(Uint8List bytes) {
  final jsonString = utf8.decode(bytes);
  final decoded = json.decode(jsonString) as List;
  return decoded
      .map((x) => (x is Map) ? x as Map<String, dynamic> : null)
      .nonNulls
      .toList(growable: false);
}
