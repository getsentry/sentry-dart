import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _IntegrationFrameCallbackHandler frameCallbackHandler;
  late SentryTransaction transaction;

  setUp(() async {
    frameCallbackHandler = _IntegrationFrameCallbackHandler();

    await SentryFlutter.init((options) {
      // ignore: invalid_use_of_internal_member
      options.automatedTestMode = true;
      options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
      options.debug = true;
      options.tracesSampleRate = 1.0;

      options.beforeSendTransaction = (tx) {
        transaction = tx;
        return tx;
      };

      final appStartIntegration = options.integrations.firstWhere(
          (integration) => integration is NativeAppStartIntegration);
      options.removeIntegration(appStartIntegration);
      options.addIntegration(NativeAppStartIntegration(
          frameCallbackHandler,
          // ignore: invalid_use_of_internal_member
          NativeAppStartHandler(SentryFlutter.native!)));
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  testWidgets('app start measurements are processed and reported',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test Widget'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(transaction.measurements, isNotEmpty);
    expect(transaction.measurements['time_to_initial_display'], isNotNull);
    expect(transaction.measurements['app_start_cold'], isNotNull);
  });
}

class _IntegrationFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    // not needed here
  }

  void Function(List<FrameTiming>)? timingsCallback;

  @override
  void addTimingsCallback(SentryTimingsCallback callback) {
    timingsCallback = callback;
    WidgetsBinding.instance.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(SentryTimingsCallback callback) {
    assert(timingsCallback != null);
    assert(timingsCallback == callback);
    WidgetsBinding.instance.removeTimingsCallback(timingsCallback!);
  }
}
