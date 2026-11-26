import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry_flutter/src/native/c/sentry_native_worker.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';
import 'sentry_native_test_ffi.dart';

/// Runs in its own process, which has not loaded sentry.dll yet.
void main() {
  late NativeTestHelper helper;
  setUpAll(
    () async => helper = await setUpNativeBackend(configuredNativeBackend),
  );

  test(
    'platform thread keeps a stack guarantee when the worker loads the library',
    () async {
      expect(
        _isModuleLoaded('sentry.dll'),
        isFalse,
        reason: 'needs a process that has not loaded sentry.dll yet',
      );
      expect(SentryNativeWorker.threadStackGuarantee(), 0);
      final sut = SentryNative(
        SentryFlutterOptions(dsn: fakeDsn)
          ..nativeDatabasePath = '${helper.nativeTestRoot}/db'
          // ignore: invalid_use_of_internal_member
          ..automatedTestMode = true,
      );
      addTearDown(sut.close);

      await sut.init(MockHub());
      await sut.worker!.initialized;

      expect(await sut.worker!.target, isNotNull);
      expect(_isModuleLoaded('sentry.dll'), isTrue);
      expect(SentryNativeWorker.threadStackGuarantee(), 64 * 1024);
    },
  );
}

bool _isModuleLoaded(String name) {
  final getModuleHandle = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Pointer<Void> Function(Pointer<Utf16>),
        Pointer<Void> Function(Pointer<Utf16>)
      >('GetModuleHandleW');
  final cName = name.toNativeUtf16();
  try {
    return getModuleHandle(cName) != nullptr;
  } finally {
    malloc.free(cName);
  }
}
