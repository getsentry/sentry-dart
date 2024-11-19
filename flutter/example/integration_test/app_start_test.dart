import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';

import '../../../dart/test/mocks/mock_transport.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App start measurement', () {
    testWidgets('is captured', (WidgetTester tester) async {
      final frameCallbackHandler = _IntegrationFrameCallbackHandler();
      final transport = MockTransport();

      await SentryFlutter.init((options) {
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
        options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
        options.debug = true;
        options.tracesSampleRate = 1.0;
        options.transport = transport;

        final appStartIntegration = options.integrations.firstWhere(
            (integration) => integration is NativeAppStartIntegration);
        options.removeIntegration(appStartIntegration);
        options.addIntegration(NativeAppStartIntegration(
            frameCallbackHandler,
            // ignore: invalid_use_of_internal_member
            NativeAppStartHandler(SentryFlutter.native!)));
      });

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

      await Future<void>.delayed(const Duration(seconds: 3));

      final envelope = transport.envelopes.first;
      expect(envelope.items[0].header.type, "transaction");
      expect(await envelope.items[0].header.length(), greaterThan(0));

      final txJson = utf8.decode(await envelope.items[0].dataFactory());
      final txData = json.decode(txJson) as Map<String, dynamic>;

      expect(txData["measurements"]["time_to_initial_display"]["value"],
          isNotNull);
      expect(txData["measurements"]["app_start_cold"]["value"], isNotNull);
    });
  },
      skip: Platform.isMacOS
          ? 'App start measurement is not supported on this platform'
          : false);
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
