import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/flutter_error_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group(FlutterErrorIntegration, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _mockValues() {
      when(fixture.hub.configureScope(captureAny)).thenAnswer((_) {});

      when(fixture.hub.captureEvent(captureAny,
              hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')))
          .thenAnswer((_) => Future.value(SentryId.empty()));

      when(fixture.hub.options).thenReturn(fixture.options);

      final tracer = MockSentryTracer();
      final span =
          SentrySpan(tracer, SentrySpanContext(operation: 'op'), fixture.hub);

      when(fixture.hub.getSpan()).thenReturn(span);
    }

    void _reportError({
      bool silent = false,
      FlutterExceptionHandler? handler,
      dynamic exception,
      FlutterErrorDetails? optionalDetails,
    }) {
      _mockValues();

      // replace default error otherwise it fails on testing
      FlutterError.onError =
          handler ?? (FlutterErrorDetails errorDetails) async {};

      final sut = fixture.getSut();
      sut(fixture.hub, fixture.options);

      final throwable = exception ?? StateError('error');
      final details = FlutterErrorDetails(
        exception: throwable as Object,
        silent: silent,
        context: DiagnosticsNode.message('while handling a gesture'),
        library: 'sentry',
        informationCollector: () => [DiagnosticsNode.message('foo bar')],
      );

      FlutterError.reportError(optionalDetails ?? details);
    }

    test('captures error', () async {
      final exception = StateError('error');

      _reportError(exception: exception);

      final event = verify(
        await fixture.hub.captureEvent(
          captureAny,
          hint: anyNamed('hint'),
          stackTrace: anyNamed('stackTrace'),
        ),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, false);
      expect(throwableMechanism.throwable, exception);

      expect(event.contexts['flutter_error_details']['library'], 'sentry');
      expect(event.contexts['flutter_error_details']['context'],
          'thrown while handling a gesture');
      expect(event.contexts['flutter_error_details']['information'], 'foo bar');
    }, onPlatform: {
      // TODO stacktrace parsing for wasm is not implemented yet
      //      https://github.com/getsentry/sentry-dart/issues/1480
      'wasm': Skip('WASM stack trace parsing not implemented yet'),
    });

    test('captures error with long FlutterErrorDetails.information', () async {
      final details = FlutterErrorDetails(
        exception: StateError('error'),
        silent: false,
        context: DiagnosticsNode.message('while handling a gesture'),
        library: 'sentry',
        informationCollector: () => [
          DiagnosticsNode.message('foo bar'),
          DiagnosticsNode.message('Hello World!')
        ],
      );

      // exception is ignored in this case
      _reportError(exception: StateError('error'), optionalDetails: details);

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, false);

      expect(event.contexts['flutter_error_details']['library'], 'sentry');
      expect(event.contexts['flutter_error_details']['context'],
          'thrown while handling a gesture');
      expect(event.contexts['flutter_error_details']['information'],
          'foo bar\nHello World!');
    }, onPlatform: {
      // TODO stacktrace parsing for wasm is not implemented yet
      //      https://github.com/getsentry/sentry-dart/issues/1480
      'wasm': Skip('WASM stack trace parsing not implemented yet'),
    });

    test('captures error with no FlutterErrorDetails', () async {
      final details = FlutterErrorDetails(
          exception: StateError('error'), silent: false, library: null);

      // exception is ignored in this case
      _reportError(exception: StateError('error'), optionalDetails: details);

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, false);
      expect(throwableMechanism.mechanism.data['hint'], isNull);

      expect(event.contexts['flutter_error_details'], isNull);
    });

    test('calls default error', () async {
      var called = false;
      final defaultError = (FlutterErrorDetails errorDetails) async {
        called = true;
      };

      _reportError(handler: defaultError);

      verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      );

      expect(called, true);
    });

    test('calls captureEvent only called once', () async {
      _mockValues();

      var numberOfDefaultCalls = 0;
      final defaultError = (FlutterErrorDetails errorDetails) async {
        numberOfDefaultCalls++;
      };
      FlutterError.onError = defaultError;

      final details = FlutterErrorDetails(exception: StateError('error'));

      final integrationA = fixture.getSut();
      integrationA.call(fixture.hub, fixture.options);
      integrationA.close();

      final integrationB = fixture.getSut();
      integrationB.call(fixture.hub, fixture.options);

      FlutterError.reportError(details);

      verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      ).called(1);

      expect(numberOfDefaultCalls, 1);
    });

    test('closes restored default onError', () {
      final defaultOnError = (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = defaultOnError;

      final integration = fixture.getSut();
      integration.call(fixture.hub, fixture.options);
      expect(false, defaultOnError == FlutterError.onError);

      integration.close();
      expect(FlutterError.onError, defaultOnError);
    });

    test('default is not restored if set after integration', () {
      final defaultOnError = (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = defaultOnError;

      final integration = fixture.getSut();
      integration.call(fixture.hub, fixture.options);
      expect(defaultOnError == FlutterError.onError, false);

      final afterIntegrationOnError =
          (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = afterIntegrationOnError;

      integration.close();
      expect(FlutterError.onError, afterIntegrationOnError);
    });

    test('captureEvent never uses an empty or null stack trace', () async {
      final exception = StateError('error');
      final details = FlutterErrorDetails(
        exception: exception,
        stack: null, // Explicitly set stack to null
      );

      _reportError(optionalDetails: details);

      final captured = verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: captureAnyNamed('stackTrace')),
      ).captured;

      final stackTrace = captured[1] as StackTrace?;

      expect(stackTrace, isNotNull);
      expect(stackTrace.toString(), isNotEmpty);
    });

    test('do not capture if silent error', () async {
      _reportError(silent: true);

      verifyNever(await fixture.hub.captureEvent(captureAny));
    });

    test('captures if silent error but reportSilentFlutterErrors', () async {
      fixture.options.reportSilentFlutterErrors = true;
      _reportError(silent: true);

      verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      );
    });

    test('adds integration', () {
      final sut = fixture.getSut();
      sut(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations.contains('flutterErrorIntegration'),
          true);
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

      // replace default error otherwise it fails on testing
      FlutterError.onError = (FlutterErrorDetails errorDetails) async {};
      sut(hub, fixture.options);

      hub.startTransaction('name', 'operation', bindToScope: true);

      FlutterError.reportError(FlutterErrorDetails(exception: exception));

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });

    test('captures error with level error', () async {
      final exception = StateError('error');

      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;

      _reportError(exception: exception);

      final event = verify(
        await fixture.hub.captureEvent(captureAny,
            hint: anyNamed('hint'), stackTrace: anyNamed('stackTrace')),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;

  FlutterErrorIntegration getSut() {
    return FlutterErrorIntegration();
  }
}
