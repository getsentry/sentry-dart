import 'dart:ffi';
import 'dart:io';

void abort() {
  final lib = Platform.isWindows
      ? DynamicLibrary.open('ucrtbase.dll')
      : DynamicLibrary.process();
  lib.lookupFunction<Void Function(), void Function()>('abort')();
}

// Raises STATUS_FAIL_FAST_EXCEPTION, which bypasses exception handlers and
// goes straight to WER.
void failFast() {
  DynamicLibrary.open('kernel32.dll').lookupFunction<
    Void Function(Pointer, Pointer, Uint32),
    void Function(Pointer, Pointer, int)
  >('RaiseFailFastException')(nullptr, nullptr, 0);
}
