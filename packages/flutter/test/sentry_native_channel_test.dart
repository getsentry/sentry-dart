// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';
import 'package:sentry_flutter/src/native/utils/data_normalizer.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  for (var mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOS(),
    MockPlatform.macOS()
  ]) {
    group('$SentryNativeBinding', () {
      late SentryNativeBinding sut;
      late MockMethodChannel channel;

      setUp(() {
        channel = MockMethodChannel();
        final options = defaultTestOptions()
          ..platform = mockPlatform
          ..methodChannel = channel;
        sut = createBinding(options);
      });

      // TODO move other methods here, e.g. init_native_sdk_test.dart

      test('fetchNativeAppStart', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.fetchNativeAppStart(), matcher);

        verifyZeroInteractions(channel);
      });

      test('setUser', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        final user = SentryUser(
          id: "fixture-id",
          data: {'object': Object()},
        );

        expect(() => sut.setUser(user), matcher);

        verifyZeroInteractions(channel);
      });

      test('addBreadcrumb', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        final breadcrumb = Breadcrumb(
          data: {'object': Object()},
        );

        expect(() => sut.addBreadcrumb(breadcrumb), matcher);

        verifyZeroInteractions(channel);
      });

      test('clearBreadcrumbs', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.clearBreadcrumbs(), matcher);

        verifyZeroInteractions(channel);
      });

      test('setContexts', () async {
        final value = {'object': Object()};
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.setContexts('fixture-key', value), matcher);

        verifyZeroInteractions(channel);
      });

      test('removeContexts', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.removeContexts('fixture-key'), matcher);

        verifyZeroInteractions(channel);
      });

      test('setExtra', () async {
        final value = {'object': Object()};
        final normalizedValue = normalize(value);
        when(channel.invokeMethod(
                'setExtra', {'key': 'fixture-key', 'value': normalizedValue}))
            .thenAnswer((_) => Future.value());

        await sut.setExtra('fixture-key', value);

        verify(channel.invokeMethod(
            'setExtra', {'key': 'fixture-key', 'value': normalizedValue}));
      });

      test('removeExtra', () async {
        when(channel.invokeMethod('removeExtra', {'key': 'fixture-key'}))
            .thenAnswer((_) => Future.value());

        await sut.removeExtra('fixture-key');

        verify(channel.invokeMethod('removeExtra', {'key': 'fixture-key'}));
      });

      test('setTag', () async {
        when(channel.invokeMethod(
                'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}))
            .thenAnswer((_) => Future.value());

        await sut.setTag('fixture-key', 'fixture-value');

        verify(channel.invokeMethod(
            'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}));
      });

      test('removeTag', () async {
        when(channel.invokeMethod('removeTag', {'key': 'fixture-key'}))
            .thenAnswer((_) => Future.value());

        await sut.removeTag('fixture-key');

        verify(channel.invokeMethod('removeTag', {'key': 'fixture-key'}));
      });

      test('startProfiler', () {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          androidUnsupported: true,
        );
        expect(() => sut.startProfiler(SentryId.newId()), matcher);

        verifyZeroInteractions(channel);
      });

      test('discardProfiler', () async {
        final traceId = SentryId.newId();
        when(channel.invokeMethod('discardProfiler', traceId.toString()))
            .thenAnswer((_) async {});

        await sut.discardProfiler(traceId);

        verify(channel.invokeMethod('discardProfiler', traceId.toString()));
      });

      test('collectProfile', () async {
        final traceId = SentryId.newId();
        const startTime = 42;
        const endTime = 50;
        when(channel.invokeMethod('collectProfile', {
          'traceId': traceId.toString(),
          'startTime': startTime,
          'endTime': endTime,
        })).thenAnswer((_) async => {});

        await sut.collectProfile(traceId, startTime, endTime);

        verify(channel.invokeMethod('collectProfile', {
          'traceId': traceId.toString(),
          'startTime': startTime,
          'endTime': endTime,
        }));
      });

      test(
        'captureEnvelope',
        () {
          when(channel.invokeMethod('captureEnvelope', any))
              .thenAnswer((_) async => {});

          final data = Uint8List.fromList([1, 2, 3]);
          sut.captureEnvelope(data, false);

          verifyZeroInteractions(channel);
        },
      );

      test('loadContexts', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.loadContexts(), matcher);

        verifyZeroInteractions(channel);
      });

      test('loadDebugImages', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
        );

        expect(
            () => sut.loadDebugImages(SentryStackTrace(frames: [])), matcher);

        verifyZeroInteractions(channel);
      });

      test('displayRefreshRate', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.displayRefreshRate(), matcher);

        verifyZeroInteractions(channel);
      });

      test('pauseAppHangTracking', () async {
        if (mockPlatform.isAndroid) {
          // Android doesn't support app hang tracking, so it should hit the assertion
          expect(() => sut.pauseAppHangTracking(), throwsAssertionError);
        } else {
          // iOS/macOS should throw FFI exceptions in tests
          final matcher = _nativeUnavailableMatcher(
            mockPlatform,
            includeLookupSymbol: true,
            includeFailedToLoadClassException: true,
          );
          expect(() => sut.pauseAppHangTracking(), matcher);
        }

        verifyZeroInteractions(channel);
      });

      test('resumeAppHangTracking', () async {
        if (mockPlatform.isAndroid) {
          // Android doesn't support app hang tracking, so it should hit the assertion
          expect(() => sut.resumeAppHangTracking(), throwsAssertionError);
        } else {
          // iOS/macOS should throw FFI exceptions in tests
          final matcher = _nativeUnavailableMatcher(
            mockPlatform,
            includeLookupSymbol: true,
            includeFailedToLoadClassException: true,
          );
          expect(() => sut.resumeAppHangTracking(), matcher);
        }

        verifyZeroInteractions(channel);
      });

      test('nativeCrash', () async {
        final matcher = _nativeUnavailableMatcher(
          mockPlatform,
          includeLookupSymbol: true,
          includeFailedToLoadClassException: true,
        );

        expect(() => sut.nativeCrash(), matcher);

        verifyZeroInteractions(channel);
      });

      test('setReplayConfig', () async {
        when(channel.invokeMethod('setReplayConfig', any))
            .thenAnswer((_) => Future.value());

        final config = ReplayConfig(
            windowWidth: 110,
            windowHeight: 220,
            width: 1.1,
            height: 2.2,
            frameRate: 3);
        await sut.setReplayConfig(config);

        if (mockPlatform.isAndroid) {
          verify(channel.invokeMethod('setReplayConfig', {
            'windowWidth': config.windowWidth,
            'windowHeight': config.windowHeight,
            'width': config.width,
            'height': config.height,
            'frameRate': config.frameRate,
          }));
        } else {
          verifyNever(channel.invokeMethod('setReplayConfig', any));
        }
      });

      test('captureReplay', () async {
        final sentryId = SentryId.newId();

        when(channel.invokeMethod('captureReplay', any))
            .thenAnswer((_) => Future.value(sentryId.toString()));

        final returnedId = await sut.captureReplay();

        verify(channel.invokeMethod('captureReplay'));
        expect(returnedId, sentryId);
      });

      test('getSession is no-op', () async {
        await sut.getSession();

        verifyZeroInteractions(channel);
      });

      test('updateSession is no-op', () async {
        await sut.updateSession(status: 'test', errors: 1);

        verifyZeroInteractions(channel);
      });

      test('captureSession is no-op', () async {
        await sut.captureSession();

        verifyZeroInteractions(channel);
      });
    });
  }
}

/// Returns a matcher for the platform-specific failures we expect when native
/// FFI/ObjC code is unavailable in unit tests.
/// We will need this until we can mock FFI/JNI code in unit tests.
/// The actual functionality is tested via integration tests.
/// https://github.com/dart-lang/native/issues/1877
Matcher _nativeUnavailableMatcher(
  MockPlatform mockPlatform, {
  bool androidUnsupported = false,
  bool includeLookupSymbol = false,
  bool includeFailedToLoadClassException = false,
}) {
  if (mockPlatform.isAndroid) {
    if (androidUnsupported) {
      return throwsUnsupportedError;
    }
    return throwsA(predicate((e) =>
        e is Error &&
        e.toString().contains('Unable to locate the helper library')));
  }

  // iOS and macOS
  return throwsA(predicate((e) {
    final message = e.toString();
    final isArgError = e is ArgumentError;
    final isException = e is Exception;

    final hasObjcLoadFail =
        isException && message.contains('Failed to load Objective-C class');
    final hasCustomLoadFail = isException &&
        includeFailedToLoadClassException &&
        message.contains('FailedToLoadClassException');

    if (mockPlatform.isMacOS) {
      final hasArgFn =
          isArgError && message.contains('Couldn\'t resolve native function');
      return hasObjcLoadFail || hasCustomLoadFail || hasArgFn;
    } else {
      // iOS
      final hasUndefinedSymbol =
          isArgError && message.contains('undefined symbol: objc_msgSend');
      final hasCouldNotResolve =
          isArgError && message.contains('Couldn\'t resolve native function');
      final hasFailedLookup = isArgError &&
          includeLookupSymbol &&
          message.contains('Failed to lookup symbol');
      return hasObjcLoadFail ||
          hasCustomLoadFail ||
          hasUndefinedSymbol ||
          hasCouldNotResolve ||
          hasFailedLookup;
    }
  }));
}
