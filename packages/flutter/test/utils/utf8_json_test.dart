import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/utils/utf8_json.dart';

void main() {
  group('decodeUtf8JsonMap', () {
    test('decodes valid UTF-8 JSON map', () {
      final map = <String, dynamic>{
        'a': 1,
        'b': 'text',
        'c': true,
        'd': {'nested': 'ok'},
        'e': [1, 2, 3]
      };
      final bytes = Uint8List.fromList(utf8.encode(json.encode(map)));

      final result = decodeUtf8JsonMap(bytes);

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('a', 1));
      expect(result, containsPair('b', 'text'));
      expect(result, containsPair('c', true));
      expect(result['d'], isA<Map<String, dynamic>>());
      expect(result['e'], isA<List<dynamic>>());
    });

    test('throws when json is not a map', () {
      final notAMapJson = '[1,2,3]';
      final bytes = Uint8List.fromList(utf8.encode(notAMapJson));

      expect(() => decodeUtf8JsonMap(bytes), throwsA(isA<TypeError>()));
    });

    test('throws when bytes are not valid UTF-8 json', () {
      final bytes = Uint8List.fromList(<int>[0xFF, 0xFE, 0xFD]);

      expect(() => decodeUtf8JsonMap(bytes), throwsA(isA<FormatException>()));
    });
  });

  group('decodeUtf8JsonListOfMaps', () {
    test('decodes list of maps, filters out non-maps', () {
      final list = [
        {'k': 'v'},
        {'num': 3},
        42,
        'string',
        [1, 2, 3],
        null,
        {
          'nested': {'ok': true}
        },
      ];
      final bytes = Uint8List.fromList(utf8.encode(json.encode(list)));

      final result = decodeUtf8JsonListOfMaps(bytes);

      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 3);
      expect(result[0], containsPair('k', 'v'));
      expect(result[1], containsPair('num', 3));
      expect(result[2]['nested'], containsPair('ok', true));
    });

    test('throws when json is not a list', () {
      final notAListJson = '{"a":1}';
      final bytes = Uint8List.fromList(utf8.encode(notAListJson));

      expect(() => decodeUtf8JsonListOfMaps(bytes), throwsA(isA<TypeError>()));
    });

    test('throws when bytes are not valid UTF-8 json', () {
      final bytes = Uint8List.fromList(<int>[0xC3, 0x28]);

      expect(() => decodeUtf8JsonListOfMaps(bytes),
          throwsA(isA<FormatException>()));
    });
  });
}
