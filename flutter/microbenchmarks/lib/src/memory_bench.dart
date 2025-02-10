import 'dart:ffi';
import 'dart:math';

import 'package:benchmarking/benchmarking.dart';
import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

Future<void> execute() async {
  final rand = Random();

  // Randomized size prevents loop optimizations of constant sized loops.
  final size = 10 * 1000 * 1000 + rand.nextInt(5);
  final dataA = Uint8List.fromList(
      List.generate(size, (index) => rand.nextInt(size) % 256));
  final byteDataA = dataA.buffer.asByteData();
  final dataB = Uint8List.fromList(dataA);
  final byteDataB = dataB.buffer.asByteData();

  listEquals(dataA, dataB) || fail('Invalid result');
  syncBenchmark('listEquals()', () => listEquals(dataA, dataB)).report();

  byteDataGetUint64(byteDataA, byteDataB) || fail('Invalid result');
  syncBenchmark(
          'byteDataGetUint64()', () => byteDataGetUint64(byteDataA, byteDataB))
      .report();

  uint64Lists(byteDataA, byteDataB) || fail('Invalid result');
  syncBenchmark('uint64Lists()', () => uint64Lists(byteDataA, byteDataB))
      .report();

  nativeMemcmp(dataA, dataB) || fail('Invalid result');
  syncBenchmark('nativeMemcmp()', () => nativeMemcmp(dataA, dataB)).report();

  final ptr = malloc.allocate<Uint8>(size);
  syncBenchmark('Uint64List.SetAll', () {
    final numWords = size ~/ 8;
    final words = ptr.cast<Uint64>().asTypedList(numWords);
    if (numWords > 0) {
      words.setAll(0, dataA.buffer.asUint64List(0, numWords));
    }

    final bytes = ptr.asTypedList(size);
    for (var i = words.lengthInBytes; i < dataA.lengthInBytes; i++) {
      bytes[i] = byteDataA.getUint8(i);
    }
  }).report();
  syncBenchmark('memcpy', () => memcpy(ptr, dataA.address, size)).report();
  syncBenchmark(
          'Uint8List.SetAll', () => ptr.asTypedList(size).setAll(0, dataA))
      .report();
  malloc.free(ptr);
}

bool byteDataGetUint64(ByteData dataA, ByteData dataB) {
  if (identical(dataA, dataB)) {
    return true;
  }
  if (dataA.lengthInBytes != dataB.lengthInBytes) {
    return false;
  }

  var pos = 0;
  final len = dataA.lengthInBytes;
  while (pos + 8 < len) {
    if (dataA.getUint64(pos) != dataB.getUint64(pos)) {
      return false;
    }
    pos += 8;
  }
  while (pos < len) {
    if (dataA.getUint8(pos) != dataB.getUint8(pos)) {
      return false;
    }
    pos++;
  }
  return true;
}

/// Compares two [Uint8List]s by comparing 8 bytes at a time.
bool uint64Lists(ByteData dataA, ByteData dataB) {
  if (identical(dataA, dataB)) {
    return true;
  }
  if (dataA.lengthInBytes != dataB.lengthInBytes) {
    return false;
  }

  final numWords = dataA.lengthInBytes ~/ 8;
  final wordsA = dataA.buffer.asUint64List(0, numWords);
  final wordsB = dataB.buffer.asUint64List(0, numWords);

  for (var i = 0; i < wordsA.length; i++) {
    if (wordsA[i] != wordsB[i]) {
      return false;
    }
  }

  // Compare any remaining bytes.
  final bytesA = dataA.buffer.asUint8List(wordsA.lengthInBytes);
  final bytesB = dataA.buffer.asUint8List(wordsA.lengthInBytes);
  for (var i = 0; i < bytesA.lengthInBytes; i++) {
    if (bytesA[i] != bytesB[i]) {
      return false;
    }
  }

  return true;
}

bool nativeMemcmp(Uint8List dataA, Uint8List dataB) {
  if (identical(dataA, dataB)) {
    return true;
  }
  if (dataA.lengthInBytes != dataB.lengthInBytes) {
    return false;
  }

  return 0 == memcmp(dataA.address, dataB.address, dataA.lengthInBytes);
}

/// Compares the first num bytes of the block of memory pointed by ptr1 to the
/// first num bytes pointed by ptr2, returning zero if they all match or a value
///  different from zero representing which is greater if they do not.
@Native<Int32 Function(Pointer, Pointer, Int32)>(symbol: 'memcmp', isLeaf: true)
external int memcmp(Pointer<Uint8> ptr1, Pointer<Uint8> ptr2, int len);

/// void* memcpy( void* dest, const void* src, std::size_t count );
@Native<Void Function(Pointer, Pointer, Int32)>(symbol: 'memcpy', isLeaf: true)
external void memcpy(Pointer<Uint8> dest, Pointer<Uint8> src, int count);
