@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/android_core_worker.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

void main() {
  // the ReplaySizeAdjustment tests assumes a constant video block size of 16
  group('ReplaySizeAdjustment', () {
    test(
      'rounds down when remainder is less than or equal to half block size',
      () {
        expect(0.0.adjustReplaySizeToBlockSize(), 0.0);
        expect(8.0.adjustReplaySizeToBlockSize(), 0.0);
        expect(16.0.adjustReplaySizeToBlockSize(), 16.0);
        expect(24.0.adjustReplaySizeToBlockSize(), 16.0);
        expect(100.0.adjustReplaySizeToBlockSize(), 96.0);
      },
    );

    test('rounds up when remainder is greater than half block size', () {
      expect(9.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(15.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(25.0.adjustReplaySizeToBlockSize(), 32.0);
      expect(108.0.adjustReplaySizeToBlockSize(), 112.0);
      expect(109.0.adjustReplaySizeToBlockSize(), 112.0);
    });

    test('returns exact value when already multiple of block size', () {
      expect(32.0.adjustReplaySizeToBlockSize(), 32.0);
      expect(48.0.adjustReplaySizeToBlockSize(), 48.0);
      expect(64.0.adjustReplaySizeToBlockSize(), 64.0);
      expect(128.0.adjustReplaySizeToBlockSize(), 128.0);
    });

    test('handles edge cases at half block size boundaries', () {
      expect(8.0.adjustReplaySizeToBlockSize(), 0.0);
      expect(24.0.adjustReplaySizeToBlockSize(), 16.0);
      expect(40.0.adjustReplaySizeToBlockSize(), 32.0);
    });

    test('handles fractional values', () {
      expect(7.5.adjustReplaySizeToBlockSize(), 0.0);
      expect(8.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(15.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(16.5.adjustReplaySizeToBlockSize(), 16.0);
      expect(24.5.adjustReplaySizeToBlockSize(), 32.0);
    });
  });

  group('CoreWorker initialization', () {
    late AndroidCoreWorker Function(SentryFlutterOptions) originalFactory;

    setUp(() {
      originalFactory = AndroidCoreWorker.factory;
    });

    tearDown(() {
      AndroidCoreWorker.factory = originalFactory;
    });

    test('starts core worker in constructor', () {
      var factoryCalled = false;
      var startCalled = false;

      AndroidCoreWorker.factory = (options) {
        factoryCalled = true;
        return _FakeCoreWorker(onStart: () => startCalled = true);
      };

      final options = SentryFlutterOptions(
        dsn: 'https://abc@def.ingest.sentry.io/1234567',
      );
      SentryNativeJava(options);

      expect(
        factoryCalled,
        isTrue,
        reason: 'Factory should be called during construction',
      );
      expect(
        startCalled,
        isTrue,
        reason: 'start() should be called during construction',
      );
    });
  });
}

/// Fake core worker for testing that tracks method calls.
class _FakeCoreWorker implements AndroidCoreWorker {
  final void Function()? onStart;

  _FakeCoreWorker({this.onStart});

  @override
  FutureOr<void> start() {
    onStart?.call();
  }

  @override
  FutureOr<void> close() {
    // No-op for testing
  }

  @override
  void captureEnvelope(
    Uint8List envelopeData,
    bool containsUnhandledException,
  ) {
    // No-op for testing
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    return null;
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    // No-op for testing
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    // No-op for testing
  }

  @override
  void setUser(SentryUser? user) {
    // No-op for testing
  }

  @override
  void setContexts(String key, value) {
    // No-op for testing
  }

  @override
  FutureOr<void> removeContexts(String key) {
    // No-op for testing
  }
}
