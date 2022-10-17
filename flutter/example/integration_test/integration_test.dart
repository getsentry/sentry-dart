import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> setupSentryAndApp(WidgetTester tester) async {
    await setupSentry(() async {
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: SentryAssetBundle(enableStructuredDataTracing: true),
        child: MyApp(),
      ));
      await tester.pumpAndSettle();
    });
  }

  Future<void> executeNative(Future<void> Function(MethodChannel) execute) async {
    try {
      final channel = MethodChannel('sentry_flutter');
      await execute(channel);
    } catch (error, stackTrace) {
      fail('error: $error stacktrace: $stackTrace');
    }
  }

  // Tests

  testWidgets('setup sentry and render app', (tester) async {
    await setupSentryAndApp(tester);

    // Find any UI element and verify it is present.
    expect(find.text('Open another Scaffold'), findsOneWidget);
  });

  if (Platform.isIOS) {
    testWidgets('setup sentry and execute loadContexts', (tester) async {
      await setupSentryAndApp(tester);

      await executeNative((channel) async {
        Map<String, dynamic>.from(
          await (channel.invokeMethod('loadContexts')),
        );
      });
    });
  }

  testWidgets('setup sentry and execute loadImageList', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      List<Map<dynamic, dynamic>>.from(
        await channel.invokeMethod('loadImageList'),
      );
    });
  });

  testWidgets('setup sentry and execute captureEnvelope', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final eventId = SentryId.newId();
      final event = SentryEvent(eventId: eventId);
      final sdkVersion = SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');
      final envelope = SentryEnvelope.fromEvent(event, sdkVersion);
      final envelopeData = <int>[];
      await envelope
          .envelopeStream(SentryOptions())
          .forEach(envelopeData.addAll);
      // https://flutter.dev/docs/development/platform-integration/platform-channels#codec
      final args = [Uint8List.fromList(envelopeData)];

      final result = await channel.invokeMethod(
          'captureEnvelope', args
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute fetchNativeAppStart', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMapMethod<String, dynamic>(
          'fetchNativeAppStart'
      );
      expect(result != null, true);
    });
  });

  testWidgets('setup sentry and execute beginNativeFrames & endNativeFrames', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      await channel.invokeMethod<void>('beginNativeFrames');

      final sentryId = SentryId.empty();

      await channel.invokeMapMethod<String, dynamic>(
          'endNativeFrames', {'id': sentryId.toString()}
      );
    });
  });

  testWidgets('setup sentry and execute setContexts', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod(
          'setContexts',
          {'key': 'fixture-key', 'value': 'fixture-value'}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute setUser', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod(
          'setUser',
          {'user': null}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute addBreadcrumb', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final breadcrumb = Breadcrumb();
      final result = await channel.invokeMethod(
          'addBreadcrumb',
          {'breadcrumb': breadcrumb.toJson()}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute clearBreadcrumbs', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod(
          'clearBreadcrumbs'
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute setExtra', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod(
          'setExtra',
          {'key': 'fixture-key', 'value': 'fixture-value'}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute removeExtra', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      await channel.invokeMethod(
          'setExtra',
          {'key': 'fixture-key', 'value': 'fixture-value'}
      );
      final result = await channel.invokeMethod(
          'removeExtra', {'key': 'fixture-key'}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute setTag', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod(
          'setTag',
          {'key': 'fixture-key', 'value': 'fixture-value'}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute removeTag', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      await channel.invokeMethod(
          'setTag',
          {'key': 'fixture-key', 'value': 'fixture-value'}
      );
      final result = await channel.invokeMethod(
          'removeTag', {'key': 'fixture-key'}
      );
      expect(result, ''); // Empty string is returned on success
    });
  });

  testWidgets('setup sentry and execute closeNativeSdk', (tester) async {
    await setupSentryAndApp(tester);

    await executeNative((channel) async {
      final result = await channel.invokeMethod('closeNativeSdk');
      expect(result, ''); // Empty string is returned on success
    });
  });
}
