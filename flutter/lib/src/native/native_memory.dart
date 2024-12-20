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

  factory NativeMemory.fromUint8List(Uint8List source) {
    final length = source.length;
    final ptr = pkg_ffi.malloc.allocate<Uint8>(length);
    if (length > 0) {
      ptr.asTypedList(length).setAll(0, source);
    }
    return NativeMemory._(ptr, length);
  }

  factory NativeMemory.fromJson(Map<dynamic, dynamic> json) {
    final length = json['length'] as int;
    final ptr = Pointer<Uint8>.fromAddress(json['address'] as int);
    return NativeMemory._(ptr, length);
  }

  /// Frees the underlying native memory.
  /// You must not use this object after freeing.
  void free() {
    pkg_ffi.malloc.free(pointer);
  }

  Uint8List asTypedList() => pointer.asTypedList(length);

  Map<String, int> toJson() => {
        'address': pointer.address,
        'length': length,
      };
}

@internal
extension Uint8ListNativeMemory on Uint8List {
  NativeMemory toNativeMemory() => NativeMemory.fromUint8List(this);
}
