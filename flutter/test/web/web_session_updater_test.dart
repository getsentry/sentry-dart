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

      when(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')))
          .thenAnswer((_) => Future<void>.value());
      when(fixture.native.captureSession())
          .thenAnswer((_) => Future<void>.value());
    });

    test('should only execute on web', () async {
      fixture.options.platform = MockPlatform(isWeb: false);

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

    group('when processing events without exceptions', () {
      test('should not update or capture session', () async {
        final sut = fixture.getSut();
        final event = SentryEvent();
        final hint = Hint();

        await sut.onBeforeSendEvent(event, hint);

        verifyNever(fixture.native.updateSession(
            status: anyNamed('status'), errors: anyNamed('errors')));
        verifyNever(fixture.native.captureSession());
      });
    });

    group('when processing handled exceptions', () {
      test(
          'should update and increment error count for first error in active session',
          () async {
        when(fixture.native.getSession())
            .thenReturn({'status': 'ok', 'errors': 0});

        final sut = fixture.getSut();
        final event = SentryEvent().copyWith(
            exceptions: [SentryException(type: 'test', value: 'test')]);
        final hint = Hint();

        await sut.onBeforeSendEvent(event, hint);

        verify(fixture.native.updateSession(status: 'ok', errors: 1)).called(1);
        verify(fixture.native.captureSession()).called(1);
      });

      test('should not update session when error count is > 0', () async {
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

      test('should not update terminal sessions even for first error',
          () async {
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

    group('when processing unhandled exceptions', () {
      test(
          'should updated and mark active sessions as crashed regardless of error count',
          () async {
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

        verify(fixture.native.updateSession(status: 'crashed', errors: 6))
            .called(1);
        verify(fixture.native.captureSession()).called(1);
      });

      test('should not update terminal sessions even for unhandled exceptions',
          () async {
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
}

class Fixture {
  final options = defaultTestOptions();
  final native = MockSentryNativeBinding();

  WebSessionUpdater getSut() {
    return WebSessionUpdater(native, options);
  }
}
