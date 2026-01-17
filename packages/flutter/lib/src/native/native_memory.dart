import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:ffi/ffi.dart' as pkg_ffi;
// ignore: implementation_imports
import 'package:sentry/src/utils/type_safe_map_access.dart';

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
    final data = Map<String, dynamic>.from(json);
    final length = data.getValueOrNull<int>('length')!;
    final address = data.getValueOrNull<int>('address')!;
    final ptr = Pointer<Uint8>.fromAddress(address);
    return NativeMemory._(ptr, length);
  }

  /// Frees the underlying native memory.
  /// You must not use this object after freeing.
  ///
  /// Currently, we only need to do this in tests because there's no native
  /// counterpart to free the memory.
  @visibleForTesting
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
