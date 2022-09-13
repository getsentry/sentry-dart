import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/on_error_integration.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'mock_platform_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  void _reportError({
    required Object exception,
    required StackTrace stackTrace,
    ErrorCallback? handler,
  }) {
    fixture.platformDispatcherWrapper.onError = handler ??
        (_, __) {
          return fixture.onErrorReturnValue;
        };

    when(fixture.hub.captureEvent(captureAny,
            stackTrace: captureAnyNamed('stackTrace')))
        .thenAnswer((_) => Future.value(SentryId.empty()));

    OnErrorIntegration(dispatchWrapper: fixture.platformDispatcherWrapper)(
      fixture.hub,
      fixture.options,
    );

    fixture.platformDispatcherWrapper.onError?.call(exception, stackTrace);
  }

  test('onError capture errors', () async {
    final exception = StateError('error');

    _reportError(exception: exception, stackTrace: StackTrace.current);

    final event = verify(
      await fixture.hub
          .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    expect(event.level, SentryLevel.fatal);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.type, 'PlatformDispatcher.onError');
    expect(throwableMechanism.mechanism.handled, true);
    expect(throwableMechanism.throwable, exception);
  });

  test('onError: handled is true if onError returns true', () async {
    fixture.onErrorReturnValue = true;
    final exception = StateError('error');
    _reportError(exception: exception, stackTrace: StackTrace.current);

    final event = verify(
      await fixture.hub
          .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.handled, true);
  });

  test('onError: handled is false if onError returns false', () async {
    fixture.onErrorReturnValue = false;
    final exception = StateError('error');
    _reportError(exception: exception, stackTrace: StackTrace.current);

    final event = verify(
      await fixture.hub
          .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.handled, false);
  });

  test('onError calls default error', () async {
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

  test('onError close restored default onError', () async {
    ErrorCallback defaultOnError = (_, __) {
      return true;
    };
    fixture.platformDispatcherWrapper.onError = defaultOnError;

    final integration =
        OnErrorIntegration(dispatchWrapper: fixture.platformDispatcherWrapper);
    integration.call(fixture.hub, fixture.options);
    expect(false, defaultOnError == fixture.platformDispatcherWrapper.onError);

    integration.close();
    expect(fixture.platformDispatcherWrapper.onError, defaultOnError);
  });

  test('FlutterError adds integration', () {
    OnErrorIntegration(dispatchWrapper: fixture.platformDispatcherWrapper)(
        fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('OnErrorIntegration'),
      true,
    );
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
  late final platformDispatcherWrapper =
      PlatformDispatcherWrapper(MockPlatformDispatcher());

  bool onErrorReturnValue = true;
}
