@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/bindings/binding_wrapper.dart';
import 'package:sentry_flutter/src/native/native_sdk_integration.dart';
import 'package:sentry_flutter/src/native/java/android_core_worker.dart';
import 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';
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
      TestWidgetsFlutterBinding.ensureInitialized();
      originalFactory = AndroidCoreWorker.factory;
      fixture = Fixture();
      AndroidCoreWorker.factory = (_) => fixture.worker;
    });

    tearDown(() {
      AndroidCoreWorker.factory = originalFactory;
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

    test('initializes the Flutter binding in its constructor', () {
      final bindingUtils = TestBindingWrapper();
      fixture.options.bindingUtils = bindingUtils;

      fixture.getSut();

      expect(bindingUtils.ensureBindingInitializedCalled, isTrue);
    });

    test('throws in automated test mode '
        'when listening for the engine detach fails', () {
      fixture.options.bindingUtils = _FailingBindingWrapper();

      expect(fixture.getSut, throwsStateError);
    });

    test('does not throw outside automated test mode '
        'when listening for the engine detach fails', () {
      fixture.options
        ..automatedTestMode = false
        ..bindingUtils = _FailingBindingWrapper();

      expect(fixture.getSut, returnsNormally);
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

    test('engineDetaching closes both workers before the call returns', () {
      final native = fixture.getSut();
      final recorder = _FakeReplayRecorder(fixture.options);
      native.testRecorder = recorder;

      fixture.sendFromPlatform(const MethodCall('engineDetaching', 7));

      expect(fixture.worker.detachToken, 7);
      expect(recorder.detachToken, 7);
      expect(native.testRecorder, isNull);
    });

    test('does not close the workers on other platform calls', () {
      final native = fixture.getSut();
      final recorder = _FakeReplayRecorder(fixture.options);
      native.testRecorder = recorder;

      fixture.sendFromPlatform(const MethodCall('somethingElse', 7));

      expect(fixture.worker.detachToken, isNull);
      expect(recorder.detachToken, isNull);
      expect(native.testRecorder, same(recorder));
    });

    test('engineDetaching closes the core worker '
        'when closing the replay recorder throws', () {
      final native = fixture.getSut();
      native.testRecorder = _FakeReplayRecorder(fixture.options)
        ..throwOnDetach = true;

      fixture.sendFromPlatform(const MethodCall('engineDetaching', 7));

      expect(fixture.worker.detachToken, 7);
    });

    test('engineDetaching completes without error '
        'when closing the core worker throws', () async {
      fixture.getSut();
      fixture.worker.throwOnDetach = true;

      final result = fixture.callFromPlatform(
        const MethodCall('engineDetaching', 7),
      );

      await expectLater(result, completes);
    });

    test('ignores engineDetaching without an int token', () async {
      final native = fixture.getSut();
      final recorder = _FakeReplayRecorder(fixture.options);
      native.testRecorder = recorder;

      final result = fixture.callFromPlatform(
        const MethodCall('engineDetaching', 'seven'),
      );

      await expectLater(result, completes);
      expect(fixture.worker.detachToken, isNull);
      expect(recorder.detachToken, isNull);
      expect(native.testRecorder, same(recorder));
    });

    test('engineDetaching closes the core worker after close()', () async {
      final native = fixture.getSut();
      await native.close();

      fixture.sendFromPlatform(const MethodCall('engineDetaching', 7));

      expect(fixture.worker.detachToken, 7);
    });

    test('engineDetaching closes the workers of the binding constructed last '
        'and not those of an earlier binding', () {
      final first = fixture.getSut();
      final firstRecorder = _FakeReplayRecorder(fixture.options);
      first.testRecorder = firstRecorder;
      final secondWorker = _FakeCoreWorker();
      AndroidCoreWorker.factory = (_) => secondWorker;
      final second = fixture.getSut();
      final secondRecorder = _FakeReplayRecorder(fixture.options);
      second.testRecorder = secondRecorder;

      fixture.sendFromPlatform(const MethodCall('engineDetaching', 7));

      expect(secondWorker.detachToken, 7);
      expect(secondRecorder.detachToken, 7);
      expect(fixture.worker.detachToken, isNull);
      expect(firstRecorder.detachToken, isNull);
    });
  });
}

/// Fake core worker for testing that tracks method calls.
class _FakeCoreWorker implements AndroidCoreWorker {
  bool started = false;
  bool closed = false;
  int? detachToken;
  bool throwOnDetach = false;

  @override
  void closeForEngineDetach(int token) {
    detachToken = token;
    if (throwOnDetach) throw StateError('core worker detach failed');
  }

  @override
  FutureOr<void> start() {
    started = true;
  }

  @override
  FutureOr<void> close() {
    closed = true;
  }

  @override
  void captureEnvelope(Uint8List envelopeData) {
    // No-op for testing
  }

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

/// Fake replay recorder that records the engine detach instead of touching a
/// worker isolate.
class _FakeReplayRecorder extends AndroidReplayRecorder {
  _FakeReplayRecorder(super.options);

  int? detachToken;
  bool throwOnDetach = false;

  @override
  void closeForEngineDetach(int token) {
    detachToken = token;
    if (throwOnDetach) throw StateError('replay recorder detach failed');
  }
}

/// Binding wrapper that cannot provide a binding, so that the method call
/// handler cannot be installed.
class _FailingBindingWrapper implements BindingWrapper {
  @override
  WidgetsBinding ensureInitialized() =>
      throw StateError('binding initialization failed');

  @override
  WidgetsBinding? get instance => null;
}

class Fixture {
  final options = defaultTestOptions();
  final worker = _FakeCoreWorker();

  SentryNativeJava getSut() => SentryNativeJava(options);

  /// Delivers [call] the way the Android plugin does. Deliberately not
  /// awaited: the plugin blocks right after dispatching it.
  void sendFromPlatform(MethodCall call) {
    unawaited(_deliver(call));
  }

  /// Delivers [call] like [sendFromPlatform] and completes with what the
  /// handler returned, or with the [PlatformException] that a handler failure
  /// is reported as.
  Future<Object?> callFromPlatform(MethodCall call) async {
    final reply = await _deliver(call);
    return const StandardMethodCodec().decodeEnvelope(reply!);
  }

  Future<ByteData?> _deliver(MethodCall call) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'sentry_flutter',
            const StandardMethodCodec().encodeMethodCall(call),
            (_) {},
          );
}
