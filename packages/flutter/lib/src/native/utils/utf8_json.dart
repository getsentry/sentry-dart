import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// `Utf8Decoder.fuse` special-cases [JsonDecoder], so this parses straight from
/// the bytes instead of materializing an intermediate [String].
final _utf8JsonDecoder = const Utf8Decoder().fuse(const JsonDecoder());

/// Encodes [data] as UTF-8 JSON.
///
/// Values JSON cannot represent — non-finite doubles in particular — are
/// encoded via their `toString()` rather than aborting the whole payload.
@internal
// ignore: invalid_use_of_internal_member
List<int> encodeUtf8Json(Object? data) => utf8JsonEncoder.convert(data);

@internal
Map<String, dynamic> decodeUtf8JsonMap(Uint8List bytes) =>
    _utf8JsonDecoder.convert(bytes) as Map<String, dynamic>;

@internal
List<Map<String, dynamic>> decodeUtf8JsonListOfMaps(Uint8List bytes) {
  final decoded = _utf8JsonDecoder.convert(bytes) as List;
  return decoded
      .map((x) => (x is Map) ? x as Map<String, dynamic> : null)
      .nonNulls
      .toList(growable: false);
}
