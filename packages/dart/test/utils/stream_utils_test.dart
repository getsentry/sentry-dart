import 'dart:typed_data';

import 'package:sentry/src/utils/stream_utils.dart';
import 'package:test/test.dart';

void main() {
  group('bufferStreamPrefix', () {
    test('buffers a chunk smaller than the cap and forwards it unchanged',
        () async {
      final (prefix, forwarded) = await bufferStreamPrefix(
        Stream.value('hello'.codeUnits),
        maxBytes: 10,
      );

      expect(prefix, 'hello'.codeUnits);
      expect(await forwarded.toList(), [
        'hello'.codeUnits,
      ]);
    });

    test('does not buffer more than maxBytes when a single chunk exceeds it',
        () async {
      final oversizedChunk = Uint8List.fromList(List.filled(100, 1));

      final (prefix, forwarded) = await bufferStreamPrefix(
        Stream.value(oversizedChunk),
        maxBytes: 10,
      );

      expect(prefix.length, 10);
      expect(await forwarded.expand((chunk) => chunk).toList(), oversizedChunk);
    });

    test('splits an overflowing chunk across multiple prior chunks', () async {
      final (prefix, forwarded) = await bufferStreamPrefix(
        Stream.fromIterable([
          [1, 2, 3],
          [4, 5, 6, 7, 8, 9, 10],
        ]),
        maxBytes: 5,
      );

      expect(prefix, [1, 2, 3, 4, 5]);
      expect(
        await forwarded.expand((chunk) => chunk).toList(),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
    });

    test('forwards chunks after the cap without re-buffering them', () async {
      final (prefix, forwarded) = await bufferStreamPrefix(
        Stream.fromIterable([
          [1, 2, 3],
          [4, 5],
          [6, 7, 8],
        ]),
        maxBytes: 3,
      );

      expect(prefix, [1, 2, 3]);
      expect(await forwarded.toList(), [
        [1, 2, 3],
        [4, 5],
        [6, 7, 8],
      ]);
    });
  });
}
