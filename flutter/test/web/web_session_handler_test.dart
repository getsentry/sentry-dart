import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/web/web_session_handler.dart';

import '../mocks.mocks.dart';

void main() {
  group('$WebSessionHandler', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.native.startSession(ignoreDuration: true))
          .thenAnswer((_) => Future<void>.value());
      when(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')))
          .thenAnswer((_) => Future<void>.value());
      when(fixture.native.captureSession())
          .thenAnswer((_) => Future<void>.value());
    });

    group('startSession', () {
      test('executes for initial route', () async {
        final sut = fixture.getSut();

        await sut.startSession(to: '/');

        verify(fixture.native.startSession(ignoreDuration: true)).called(1);
      });

      test('executes if routes are different', () async {
        final sut = fixture.getSut();

        await sut.startSession(from: 'from', to: 'to');

        verify(fixture.native.startSession(ignoreDuration: true)).called(1);
      });

      test('does not execute for same route', () async {
        final sut = fixture.getSut();

        await sut.startSession(from: 'same', to: 'same');

        verifyNever(fixture.native.startSession(ignoreDuration: true));
      });
    });

    group('updateSessionFromEvent', () {
      test('ignores events without exceptions', () async {
        final sut = fixture.getSut();
        final event = SentryEvent();

        await sut.updateSessionFromEvent(event);

        verifyNever(fixture.native.updateSession(
            status: anyNamed('status'), errors: anyNamed('errors')));
        verifyNever(fixture.native.captureSession());
      });

      group('with handled exceptions', () {
        test('increments error count for first error', () async {
          when(fixture.native.getSession())
              .thenReturn({'status': 'ok', 'errors': 0});

          final sut = fixture.getSut();
          final event = SentryEvent().copyWith(
              exceptions: [SentryException(type: 'test', value: 'test')]);

          await sut.updateSessionFromEvent(event);

          verify(fixture.native.updateSession(status: 'ok', errors: 1))
              .called(1);
          verify(fixture.native.captureSession()).called(1);
        });

        test('with ignores subsequent errors', () async {
          when(fixture.native.getSession())
              .thenReturn({'status': 'ok', 'errors': 1});

          final sut = fixture.getSut();
          final event = SentryEvent().copyWith(exceptions: [
            SentryException(
              type: 'test',
              value: 'test',
            )
          ]);

          await sut.updateSessionFromEvent(event);

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

          await sut.updateSessionFromEvent(event);

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

          await sut.updateSessionFromEvent(event);

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

          await sut.updateSessionFromEvent(event);

          verifyNever(fixture.native.updateSession(
              status: anyNamed('status'), errors: anyNamed('errors')));
          verifyNever(fixture.native.captureSession());
        });
      });
    });
  });
}

class Fixture {
  final native = MockSentryNativeBinding();

  WebSessionHandler getSut() {
    return WebSessionHandler(native);
  }
}
