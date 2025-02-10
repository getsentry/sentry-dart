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
    memcpy(ptr, source.buffer.asUint8List().address, lengthInBytes);
    return NativeMemory._(ptr, lengthInBytes);
  }

  factory NativeMemory.fromJson(Map<dynamic, dynamic> json) {
    final length = json['length'] as int;
    final ptr = Pointer<Uint8>.fromAddress(json['address'] as int);
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

/// void* memcpy( void* dest, const void* src, std::size_t count );
@Native<Void Function(Pointer, Pointer, Int32)>(symbol: 'memcpy', isLeaf: true)
external void memcpy(Pointer<Uint8> dest, Pointer<Uint8> src, int count);
