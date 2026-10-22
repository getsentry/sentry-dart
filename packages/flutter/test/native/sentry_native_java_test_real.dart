@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/native_sdk_integration.dart';
import 'package:sentry_flutter/src/native/java/android_core_worker.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

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

  group('$SentryNativeJava', () {
    late Fixture fixture;
    late AndroidCoreWorker Function(SentryFlutterOptions) originalFactory;

    setUp(() {
      originalFactory = AndroidCoreWorker.factory;
      fixture = Fixture();
      AndroidCoreWorker.factory = (_) => fixture.worker;
    });

    tearDown(() {
      AndroidCoreWorker.factory = originalFactory;
    });

    test('waits for delayed core worker envelope submission', () async {
      final submitted = Completer<void>();
      fixture.worker.capturing = submitted.future;
      final native = fixture.getSut();
      var captured = false;
      final capturing = Future<void>.value(
        native.captureEnvelope(Uint8List.fromList([1])),
      ).then((_) => captured = true);

      await pumpEventQueue();
      expect(captured, isFalse);
      submitted.complete();
      await capturing;
      expect(captured, isTrue);
    });

    test('stops the worker on detach without closing the SDK', () async {
      fixture.getSut();

      await fixture.lifecycle(['resumed', 'detached']);

      expect(fixture.worker.stopCount, 1);
      expect(fixture.worker.closed, isFalse);
    });

    test('restarts the worker when a detached engine resumes', () async {
      fixture.getSut();
      await fixture.lifecycle(['resumed', 'detached']);
      final startsBeforeResume = fixture.worker.startCount;

      await fixture.lifecycle(['resumed']);

      expect(fixture.worker.startCount, startsBeforeResume + 1);
    });

    test('keeps the worker running while paused', () async {
      fixture.getSut();

      await fixture.lifecycle(['resumed', 'paused']);

      expect(fixture.worker.stopCount, 0);
      expect(fixture.worker.closed, isFalse);
    });

    test('removes lifecycle callbacks when the SDK closes', () async {
      final native = fixture.getSut();
      await native.close();
      final startsBeforeResume = fixture.worker.startCount;

      await fixture.lifecycle(['detached', 'resumed']);

      expect(fixture.worker.startCount, startsBeforeResume);
      expect(fixture.worker.stopCount, 0);
    });

    test('closes the worker explicitly after detach and reattach', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      fixture.options
        ..autoInitializeNativeSdk = false
        ..bindingUtils = TestBindingWrapper();
      final integration = NativeSdkIntegration(fixture.getSut());
      await integration.call(MockHub(), fixture.options);
      addTearDown(integration.close);

      for (final state in ['resumed', 'detached', 'resumed']) {
        await binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage('AppLifecycleState.$state'),
          (_) {},
        );
      }
      await integration.close();

      expect(fixture.worker.closed, isTrue);
    });

    test('starts core worker in constructor', () {
      fixture.getSut();

      expect(fixture.worker.started, isTrue);
    });

    test(
      'close() closes the core worker synchronously, before its first await',
      () async {
        final native = fixture.getSut();

        final closeFuture = native.close();
        expect(fixture.worker.closed, isTrue);

        await closeFuture;
      },
    );
  });
}

/// Fake core worker for testing that tracks method calls.
class _FakeCoreWorker implements AndroidCoreWorker {
  Future<void>? capturing;
  bool started = false;
  bool closed = false;
  int stopCount = 0;
  int startCount = 0;

  @override
  void stop() {
    stopCount++;
  }

  @override
  FutureOr<void> start() {
    started = true;
    startCount++;
  }

  @override
  FutureOr<void> close() {
    closed = true;
  }

  @override
  FutureOr<void> captureEnvelope(Uint8List envelopeData) => capturing;

  @override
  FutureOr<void> updateSessionForDroppedEventNonTerminating(bool unhandled) {
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

class Fixture {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final options = defaultTestOptions();
  final worker = _FakeCoreWorker();

  SentryNativeJava getSut() {
    final native = SentryNativeJava(options);
    addTearDown(native.close);
    return native;
  }

  Future<void> lifecycle(List<String> states) async {
    for (final state in states) {
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.$state'),
        (_) {},
      );
    }
  }
}
