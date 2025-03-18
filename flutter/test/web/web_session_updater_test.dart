import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/src/web_session_updater.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$WebSessionUpdater', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      fixture.options.navigatorObserverRegistered = true;
      fixture.options.enableAutoSessionTracking = true;

      when(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')))
          .thenAnswer((_) => Future<void>.value());
      when(fixture.native.captureSession())
          .thenAnswer((_) => Future<void>.value());
    });

    group('on web platform', () {
      setUp(() {
        fixture.options.platform = MockPlatform(isWeb: true);
      });

      group('initialization conditions', () {
        test('skips updates when navigator observer not registered', () async {
          fixture.options.navigatorObserverRegistered = false;

          final sut = fixture.getSut();
          final event = SentryEvent().copyWith(
              exceptions: [SentryException(type: 'test', value: 'test')]);
          final hint = Hint();

          await sut.onBeforeSendEvent(event, hint);

          verifyNever(fixture.native.getSession());
          verifyNever(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')));
          verifyNever(fixture.native.captureSession());
        });

        test('skips updates when auto session tracking disabled', () async {
          fixture.options.enableAutoSessionTracking = false;

          final sut = fixture.getSut();
          final event = SentryEvent().copyWith(
              exceptions: [SentryException(type: 'test', value: 'test')]);
          final hint = Hint();

          await sut.onBeforeSendEvent(event, hint);

          verifyNever(fixture.native.getSession());
          verifyNever(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')));
          verifyNever(fixture.native.captureSession());
        });
      });

      group('event processing', () {
        test('ignores events without exceptions', () async {
          final sut = fixture.getSut();
          final event = SentryEvent();
          final hint = Hint();

          await sut.onBeforeSendEvent(event, hint);

          verifyNever(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')));
          verifyNever(fixture.native.captureSession());
        });

        group('handled exceptions', () {
          test('increments error count for first error', () async {
            when(fixture.native.getSession())
                .thenReturn({'status': 'ok', 'errors': 0});

            final sut = fixture.getSut();
            final event = SentryEvent().copyWith(
                exceptions: [SentryException(type: 'test', value: 'test')]);
            final hint = Hint();

            await sut.onBeforeSendEvent(event, hint);

            verify(fixture.native.updateSession(status: 'ok', errors: 1))
                .called(1);
            verify(fixture.native.captureSession()).called(1);
          });

          test('ignores subsequent errors', () async {
            when(fixture.native.getSession())
                .thenReturn({'status': 'ok', 'errors': 1});

            final sut = fixture.getSut();
            final event = SentryEvent().copyWith(exceptions: [
              SentryException(
                type: 'test',
                value: 'test',
              )
            ]);
            final hint = Hint();

            await sut.onBeforeSendEvent(event, hint);

            verifyNever(fixture.native.updateSession(
                status: anyNamed('status'), errors: anyNamed('errors')));
            verifyNever(fixture.native.captureSession());
          });

          test('ignores terminal sessions', () async {
            when(fixture.native.getSession())
                .thenReturn({'status': 'exit', 'errors': 0});

            final sut = fixture.getSut();
            final event = SentryEvent().copyWith(
                exceptions: [SentryException(type: 'test', value: 'test')]);
            final hint = Hint();

            await sut.onBeforeSendEvent(event, hint);

            verifyNever(fixture.native.updateSession(
                status: anyNamed('status'), errors: anyNamed('errors')));
            verifyNever(fixture.native.captureSession());
          });
        });

        group('unhandled exceptions', () {
          test('marks active sessions as crashed', () async {
            when(fixture.native.getSession())
                .thenReturn({'status': 'ok', 'errors': 5});

            final sut = fixture.getSut();
            final event = SentryEvent().copyWith(exceptions: [
              SentryException(
                  type: 'test',
                  value: 'test',
                  mechanism: Mechanism(type: 'test', handled: false))
            ]);
            final hint = Hint();

            await sut.onBeforeSendEvent(event, hint);

            verify(fixture.native.updateSession(status: 'crashed', errors: 5))
                .called(1);
            verify(fixture.native.captureSession()).called(1);
          });

          test('ignores terminal sessions', () async {
            when(fixture.native.getSession())
                .thenReturn({'status': 'exit', 'errors': 5});

            final sut = fixture.getSut();
            final event = SentryEvent().copyWith(exceptions: [
              SentryException(
                  type: 'test',
                  value: 'test',
                  mechanism: Mechanism(type: 'test', handled: false))
            ]);
            final hint = Hint();

            await sut.onBeforeSendEvent(event, hint);

            verifyNever(fixture.native.updateSession(
                status: anyNamed('status'), errors: anyNamed('errors')));
            verifyNever(fixture.native.captureSession());
          });
        });
      });
    });

    group('on non-web platform', () {
      setUp(() {
        fixture.options.platform = MockPlatform(isWeb: false);
      });

      test('no session updates', () async {
        final sut = fixture.getSut();
        final event = SentryEvent().copyWith(exceptions: [
          SentryException(
            type: 'test',
            value: 'test',
          )
        ]);
        final hint = Hint();

        await sut.onBeforeSendEvent(event, hint);

        verifyNever(fixture.native.getSession());
        verifyNever(fixture.native.updateSession(
            status: anyNamed('status'), errors: anyNamed('errors')));
        verifyNever(fixture.native.captureSession());
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final native = MockSentryNativeBinding();

  WebSessionUpdater getSut() {
    return WebSessionUpdater(native, options);
  }
}
