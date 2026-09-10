@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_sdk_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'fixture.dart';

Future<void> _sendLifecycle(String event) async {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  final message = const StringCodec().encodeMessage('AppLifecycleState.$event');
  await messenger.handlePlatformMessage('flutter/lifecycle', message, (_) {});
}

void main() {
  group(NativeSdkIntegration, () {
    late IntegrationTestFixture<NativeSdkIntegration> fixture;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      fixture = IntegrationTestFixture(NativeSdkIntegration.new);
      fixture.options.bindingUtils = TestBindingWrapper();
      when(fixture.binding.init(any)).thenReturn(null);
      when(fixture.binding.close(isExplicit: anyNamed('isExplicit')))
          .thenReturn(null);
    });

    // Every call() registers a lifecycle observer on the shared, real
    // TestWidgetsFlutterBinding singleton. Without this it outlives the
    // test and reacts to later tests' lifecycle events too.
    tearDown(() async {
      await fixture.sut.close();
    });

    test('adds integration', () async {
      await fixture.registerIntegration();
      expect(
          fixture.options.sdk.integrations, contains('nativeSdkIntegration'));
      verify(fixture.binding.init(any)).called(1);
    });

    test('does not throw', () async {
      fixture.options.automatedTestMode = false;

      fixture.sut = NativeSdkIntegration(_ThrowingMockSentryNative());
      await fixture.registerIntegration();
      expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
          false);
    });

    test('rethrows in tests', () async {
      fixture.sut = NativeSdkIntegration(_ThrowingMockSentryNative());
      expect(fixture.registerIntegration, throwsException);
      expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
          false);
    });

    test('closes native SDK', () async {
      await fixture.registerIntegration();
      await fixture.sut.close();
      verify(fixture.binding.close(isExplicit: true)).called(1);
    });

    test('does not call native sdk when auto init disabled', () async {
      fixture.options.autoInitializeNativeSdk = false;
      await fixture.registerIntegration();
      verifyNever(fixture.binding.init(any));
    });

    test('closes native even when auto init disabled', () async {
      // The native binding starts background resources unconditionally
      // (e.g. Android's AndroidCoreWorker), regardless of this flag, so
      // close() must always be reachable to stop them. See #3960.
      fixture.options.autoInitializeNativeSdk = false;
      await fixture.registerIntegration();
      await fixture.sut.close();
      verify(fixture.binding.close(isExplicit: true)).called(1);
    });

    test('is not added in case of an exception', () async {
      fixture.sut = NativeSdkIntegration(_ThrowingMockSentryNative());
      expect(fixture.registerIntegration, throwsException);
      expect(fixture.options.sdk.integrations, <String>[]);
    });

    test('closes native binding when app lifecycle becomes detached', () async {
      await fixture.registerIntegration();

      // A prior test may have already left the shared, real
      // TestWidgetsFlutterBinding singleton in the detached state, in which
      // case re-sending 'detached' is a no-op - force a state change first.
      await _sendLifecycle('resumed');
      await _sendLifecycle('detached');

      // isExplicit: false - a detach isn't necessarily terminal (e.g. a
      // cached engine may reattach later), so resources safe to keep across
      // that (Android's core worker isolate) must be told not to close.
      verify(fixture.binding.close(isExplicit: false)).called(1);
    });

    test(
        'logs a fatal error instead of leaking an unhandled future error '
        'when detached close fails', () async {
      fixture.options.automatedTestMode = false;
      when(fixture.binding.close(isExplicit: anyNamed('isExplicit')))
          .thenAnswer((_) async => throw Exception());

      SentryLevel? loggedLevel;
      // ignore: invalid_use_of_internal_member
      SentryInternalLogger.configure(
        isEnabled: true,
        minLevel: SentryLevel.fatal,
        logOutput: ({
          required String name,
          required SentryLevel level,
          required String message,
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedLevel = level;
        },
      );
      addTearDown(() =>
          // ignore: invalid_use_of_internal_member
          SentryInternalLogger.configure(isEnabled: false));

      await fixture.registerIntegration();
      // A prior test may have already left the shared, real
      // TestWidgetsFlutterBinding singleton in the detached state, in which
      // case re-sending 'detached' is a no-op - force a state change first.
      await _sendLifecycle('resumed');
      await _sendLifecycle('detached');
      // Let the unawaited close's async tail run.
      await pumpEventQueue();

      expect(loggedLevel, SentryLevel.fatal);
    });

    test('does not close native binding on other lifecycle changes', () async {
      await fixture.registerIntegration();

      await _sendLifecycle('inactive');
      await _sendLifecycle('paused');
      await _sendLifecycle('resumed');

      verifyNever(fixture.binding.close(isExplicit: anyNamed('isExplicit')));
    });

    test('does not observe lifecycle in multi-view apps', () async {
      fixture.options.isMultiViewApp = true;
      await fixture.registerIntegration();

      await _sendLifecycle('detached');

      verifyNever(fixture.binding.close(isExplicit: anyNamed('isExplicit')));
    });

    test('does not close native binding twice when detach precedes close',
        () async {
      await fixture.registerIntegration();

      await _sendLifecycle('resumed');
      await _sendLifecycle('detached');
      await fixture.sut.close();

      // Known limitation (see _closeNative's doc comment): the detach call
      // that already ran (isExplicit: false) wins - the later explicit
      // close() just awaits it rather than re-invoking with isExplicit:
      // true, so this stays at exactly 1 call total.
      verify(fixture.binding.close(isExplicit: false)).called(1);
      verifyNever(fixture.binding.close(isExplicit: true));
    });

    test('stops observing lifecycle after close', () async {
      await fixture.registerIntegration();

      await fixture.sut.close();
      clearInteractions(fixture.binding);
      await _sendLifecycle('detached');

      verifyNever(fixture.binding.close(isExplicit: anyNamed('isExplicit')));
    });
  });
}

class _ThrowingMockSentryNative extends MockSentryNativeBinding {
  @override
  Future<void> init(Hub? hub) async {
    throw Exception();
  }

  @override
  Future<void> close({bool? isExplicit = true}) async {}
}
