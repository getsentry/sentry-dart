import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:ffi/ffi.dart' as pkg_ffi;

@internal
@immutable
class NativeMemory {
  final Pointer<Uint8> pointer;
  final int length;

  const NativeMemory._(this.pointer, this.length);

  factory NativeMemory.fromByteData(ByteData source) {
    final lengthInBytes = source.lengthInBytes;
    final ptr = pkg_ffi.malloc.allocate<Uint8>(lengthInBytes);

    // TODO memcpy() from source.buffer.asUint8List().address
    //      once we can depend on Dart SDK 3.5+
    final numWords = lengthInBytes ~/ 8;
    final words = ptr.cast<Uint64>().asTypedList(numWords);
    if (numWords > 0) {
      words.setAll(0, source.buffer.asUint64List(0, numWords));
    }

    final bytes = ptr.asTypedList(lengthInBytes);
    for (var i = words.lengthInBytes; i < source.lengthInBytes; i++) {
      bytes[i] = source.getUint8(i);
    }

    return NativeMemory._(ptr, lengthInBytes);
  }

  factory NativeMemory.fromJson(Map<dynamic, dynamic> json) {
    final length = json['length'] as int;
    final ptr = Pointer<Uint8>.fromAddress(json['address'] as int);
    return NativeMemory._(ptr, length);
  }

  bool hasSameContentAs(NativeMemory other) {
    if (length != other.length) {
      return false;
    }
    if (length == 0) {
      return true;
    }
    return 0 == _memcmp(pointer, other.pointer, length);
  }

  /// Frees the underlying native memory.
  /// You must not use this object after freeing.
  void free() => pkg_ffi.malloc.free(pointer);

  Uint8List asTypedList() => pointer.asTypedList(length);

  Map<String, int> toJson() => {
        'address': pointer.address,
        'length': length,
      };
}

@internal
extension ByteDataNativeMemory on ByteData {
  NativeMemory toNativeMemory() => NativeMemory.fromByteData(this);
}

/// Compares the first num bytes of the block of memory pointed by ptr1 to the
/// first num bytes pointed by ptr2, returning zero if they all match or a value
///  different from zero representing which is greater if they do not.
/// Note: unlike the actual native memcmp, our dart fallback only returns 0/1.
final _memcmp = () {
  // try {
  return DynamicLibrary.process().lookupFunction<
      Int32 Function(Pointer<Uint8>, Pointer<Uint8>, IntPtr),
      int Function(Pointer<Uint8>, Pointer<Uint8>, int)>('memcmp');
  // } catch (_) {
  //   return (Pointer<Uint8> ptrA, Pointer<Uint8> ptrB, int len) {
  //     late final int processed;
  //     try {
  //       final numWords = len ~/ 8;
  //       final wordsA = ptrA.cast<Uint64>().asTypedList(numWords);
  //       final wordsB = ptrB.cast<Uint64>().asTypedList(numWords);

  //       for (var i = 0; i < wordsA.length; i++) {
  //         if (wordsA[i] != wordsB[i]) {
  //           return 1;
  //         }
  //       }
  //       processed = wordsA.lengthInBytes;
  //     } on UnsupportedError {
  //       // This should only trigger on dart2js:
  //       // Unsupported operation: Uint64List not supported by dart2js.
  //       processed = 0;
  //     }

  //     // Compare any remaining bytes.
  //     final bytesA = ptrA.asTypedList(processed);
  //     final bytesB = ptrB.asTypedList(processed);
  //     for (var i = processed; i < bytesA.lengthInBytes; i++) {
  //       if (bytesA[i] != bytesB[i]) {
  //         return 1;
  //       }
  //     }

  //     return 0;
  //   };
  // }
}();
