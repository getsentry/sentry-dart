import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Creates and collects native pointers that need to be freed.
class FreeableFactory {
  List<Pointer> _allocated = [];

  Pointer<Char> str(String? dartString) {
    if (dartString == null) {
      return nullptr;
    }
    final ptr = dartString.toNativeUtf8();
    _allocated.add(ptr);
    return ptr.cast();
  }

  void freeAll() {
    for (final ptr in _allocated) {
      malloc.free(ptr);
    }
    _allocated.clear();
  }
}
