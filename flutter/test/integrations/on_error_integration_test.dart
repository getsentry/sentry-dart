import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/on_error_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'mock_platform_dispatcher.dart';

void main() {
  group(OnErrorIntegration, () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _reportError({
      required Object exception,
      required StackTrace stackTrace,
      ErrorCallback? handler,
      bool onErrorReturnValue = true,
    }) {
      fixture.platformDispatcherWrapper.onError = handler ??
          (_, __) {
            return onErrorReturnValue;
          };

      when(fixture.hub.captureEvent(captureAny,
              stackTrace: captureAnyNamed('stackTrace')))
          .thenAnswer((_) => Future.value(SentryId.empty()));

      when(fixture.hub.options).thenReturn(fixture.options);
      final tracer = MockSentryTracer();
      final span =
          SentrySpan(tracer, SentrySpanContext(operation: 'op'), fixture.hub);

      when(fixture.hub.getSpan()).thenReturn(span);
      when(fixture.hub.configureScope(captureAny)).thenAnswer((_) {});

      final sut = fixture.getSut();
      sut(fixture.hub, fixture.options);

      fixture.platformDispatcherWrapper.onError?.call(exception, stackTrace);
    }

    test('captures error', () async {
      final exception = StateError('error');

      _reportError(exception: exception, stackTrace: StackTrace.current);

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            stackTrace: captureAnyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'PlatformDispatcher.onError');
      expect(throwableMechanism.mechanism.handled, true);
      expect(throwableMechanism.throwable, exception);
    });

    test('handled is true if onError returns true', () async {
      final exception = StateError('error');
      _reportError(exception: exception, stackTrace: StackTrace.current);

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            stackTrace: captureAnyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.handled, true);
    });

    test('handled is false if onError returns false', () async {
      final exception = StateError('error');
      _reportError(
        exception: exception,
        stackTrace: StackTrace.current,
        onErrorReturnValue: false,
      );

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            stackTrace: captureAnyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.handled, false);
    });

    test('captureEvent never uses an empty or null stack trace', () async {
      final exception = StateError('error');
      _reportError(
        exception: exception,
        stackTrace: StackTrace.current,
        onErrorReturnValue: false,
      );

      final captured = verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: captureAnyNamed('stackTrace')),
      ).captured;

      final stackTrace = captured[1] as StackTrace?;

      expect(stackTrace, isNotNull);
      expect(stackTrace.toString(), isNotEmpty);
    });

    test('calls default error', () async {
      var called = false;
      final defaultError = (_, __) {
        called = true;
        return true;
      };

      _reportError(
        exception: Exception(),
        stackTrace: StackTrace.current,
        handler: defaultError,
      );

      verify(await fixture.hub.captureEvent(
        captureAny,
        stackTrace: captureAnyNamed('stackTrace'),
      ));

      expect(called, true);
    });

    test('closes restored default onError', () async {
      ErrorCallback defaultOnError = (_, __) {
        return true;
      };
      fixture.platformDispatcherWrapper.onError = defaultOnError;

      final sut = fixture.getSut();
      sut(fixture.hub, fixture.options);
      expect(
          false, defaultOnError == fixture.platformDispatcherWrapper.onError);

      sut.close();
      expect(fixture.platformDispatcherWrapper.onError, defaultOnError);
    });

    test('adds integration', () {
      final sut = fixture.getSut();
      sut(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations.contains('OnErrorIntegration'),
        true,
      );
    });

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      when(client.captureEvent(any,
              scope: anyNamed('scope'),
              stackTrace: anyNamed('stackTrace'),
              hint: anyNamed('hint')))
          .thenAnswer((_) => Future.value(SentryId.newId()));
      when(client.captureTransaction(any,
              scope: anyNamed('scope'), traceContext: anyNamed('traceContext')))
          .thenAnswer((_) => Future.value(SentryId.newId()));
      hub.bindClient(client);

      final sut = fixture.getSut();

      sut(hub, fixture.options);

      hub.startTransaction('name', 'operation', bindToScope: true);

      fixture.platformDispatcherWrapper.onError
          ?.call(exception, StackTrace.current);

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
  final platformDispatcherWrapper =
      PlatformDispatcherWrapper(MockPlatformDispatcher());

  OnErrorIntegration getSut() {
    return OnErrorIntegration(dispatchWrapper: platformDispatcherWrapper);
  }
}
