import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

@internal
class WindowsLibraryLoader {
  WindowsLibraryLoader(DynamicLibrary kernel32)
      : _load = kernel32.lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Void>, Uint32),
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Void>, int)>(
          'LoadLibraryExW',
          isLeaf: false,
        ),
        _lastError = kernel32
            .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

  final Pointer<Void> Function(Pointer<Utf16>, Pointer<Void>, int) _load;
  final int Function() _lastError;

  void load(String path) {
    final name = path.toNativeUtf16();
    try {
      // Zero flags preserve DynamicLibrary.open's Windows search policy.
      // A non-leaf call lets other isolates collect garbage during DLL loading.
      if (_load(name, nullptr, 0) == nullptr) {
        throw OSError('Failed to load dynamic library "$path"', _lastError());
      }
      // Retain the OS reference across helper exit and all native callbacks.
    } finally {
      calloc.free(name);
    }
  }
}
