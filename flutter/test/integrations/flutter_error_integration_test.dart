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

    void _reportError({
      bool silent = false,
      FlutterExceptionHandler? handler,
      dynamic exception,
      FlutterErrorDetails? optionalDetails,
    }) {
      // replace default error otherwise it fails on testing
      FlutterError.onError =
          handler ?? (FlutterErrorDetails errorDetails) async {};

      when(fixture.hub.captureEvent(captureAny))
          .thenAnswer((_) => Future.value(SentryId.empty()));

      FlutterErrorIntegration()(fixture.hub, fixture.options);

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

    test('FlutterError capture errors', () async {
      final exception = StateError('error');

      _reportError(exception: exception);

      final event = verify(
        await fixture.hub.captureEvent(captureAny),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, true);
      expect(throwableMechanism.throwable, exception);

      expect(event.contexts['flutter_error_details']['library'], 'sentry');
      expect(event.contexts['flutter_error_details']['context'],
          'thrown while handling a gesture');
      expect(event.contexts['flutter_error_details']['information'], 'foo bar');
    });

    test(
        'FlutterError capture errors with long FlutterErrorDetails.information',
        () async {
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
        await fixture.hub.captureEvent(captureAny),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, true);

      expect(event.contexts['flutter_error_details']['library'], 'sentry');
      expect(event.contexts['flutter_error_details']['context'],
          'thrown while handling a gesture');
      expect(event.contexts['flutter_error_details']['information'],
          'foo bar\nHello World!');
    });

    test('FlutterError capture errors with no FlutterErrorDetails', () async {
      final details = FlutterErrorDetails(
          exception: StateError('error'), silent: false, library: null);

      // exception is ignored in this case
      _reportError(exception: StateError('error'), optionalDetails: details);

      final event = verify(
        await fixture.hub.captureEvent(captureAny),
      ).captured.first as SentryEvent;

      expect(event.level, SentryLevel.fatal);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect(throwableMechanism.mechanism.type, 'FlutterError');
      expect(throwableMechanism.mechanism.handled, true);
      expect(throwableMechanism.mechanism.data['hint'], isNull);

      expect(event.contexts['flutter_error_details'], isNull);
    });

    test('FlutterError calls default error', () async {
      var called = false;
      final defaultError = (FlutterErrorDetails errorDetails) async {
        called = true;
      };

      _reportError(handler: defaultError);

      verify(await fixture.hub.captureEvent(captureAny));

      expect(called, true);
    });

    test('FlutterErrorIntegration captureEvent only called once', () async {
      var numberOfDefaultCalls = 0;
      final defaultError = (FlutterErrorDetails errorDetails) async {
        numberOfDefaultCalls++;
      };
      FlutterError.onError = defaultError;

      when(fixture.hub.captureEvent(captureAny))
          .thenAnswer((_) => Future.value(SentryId.empty()));

      final details = FlutterErrorDetails(exception: StateError('error'));

      final integrationA = FlutterErrorIntegration();
      integrationA.call(fixture.hub, fixture.options);
      await integrationA.close();

      final integrationB = FlutterErrorIntegration();
      integrationB.call(fixture.hub, fixture.options);

      FlutterError.reportError(details);

      verify(await fixture.hub.captureEvent(captureAny)).called(1);

      expect(numberOfDefaultCalls, 1);
    });

    test('FlutterErrorIntegration close restored default onError', () async {
      final defaultOnError = (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = defaultOnError;

      final integration = FlutterErrorIntegration();
      integration.call(fixture.hub, fixture.options);
      expect(false, defaultOnError == FlutterError.onError);

      await integration.close();
      expect(FlutterError.onError, defaultOnError);
    });

    test(
        'FlutterErrorIntegration default not restored if set after integration',
        () async {
      final defaultOnError = (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = defaultOnError;

      final integration = FlutterErrorIntegration();
      integration.call(fixture.hub, fixture.options);
      expect(defaultOnError == FlutterError.onError, false);

      final afterIntegrationOnError =
          (FlutterErrorDetails errorDetails) async {};
      FlutterError.onError = afterIntegrationOnError;

      await integration.close();
      expect(FlutterError.onError, afterIntegrationOnError);
    });

    test('FlutterError do not capture if silent error', () async {
      _reportError(silent: true);

      verifyNever(await fixture.hub.captureEvent(captureAny));
    });

    test('FlutterError captures if silent error but reportSilentFlutterErrors',
        () async {
      fixture.options.reportSilentFlutterErrors = true;
      _reportError(silent: true);

      verify(await fixture.hub.captureEvent(captureAny));
    });

    test('FlutterError adds integration', () {
      FlutterErrorIntegration()(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations.contains('flutterErrorIntegration'),
          true);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
}
