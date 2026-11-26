// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_webview_flutter/sentry_webview_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('$SentryWebViewTracing', () {
    const channel = MethodChannel('sentry_flutter/webview_tracing');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final controller = WebViewController.fromPlatform(_AndroidController());
    setUp(() async {
      await Sentry.init((o) => o.dsn = 'https://key@example.invalid/1');
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await Sentry.close();
    });

    test(
      'returns false and records adoption when document-start is unavailable',
      () async {
        MethodCall? received;
        messenger.setMockMethodCallHandler(channel, (call) async {
          received = call;
          return false;
        });
        final installed = await SentryWebViewTracing.addTracePropagation(
          controller,
          allowedHosts: ['shop.example'],
        );
        expect(installed, isFalse);
        expect(received?.arguments['identifier'], 42);
        expect(
          received?.arguments['origins'],
          unorderedEquals(['https://shop.example', 'https://*.shop.example']),
        );
        expect(
          Sentry.currentHub.options.sdk.integrations,
          contains('WebViewTracePropagation'),
        );
      },
    );

    test('contains native registration errors', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(
        await SentryWebViewTracing.addTracePropagation(
          controller,
          allowedHosts: ['shop.example'],
        ),
        isFalse,
      );
    });

    test('clears an earlier registration when the SDK is disabled', () async {
      await Sentry.close();
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return false;
      });
      expect(
        await SentryWebViewTracing.addTracePropagation(
          controller,
          allowedHosts: ['shop.example'],
        ),
        isFalse,
      );
      expect(received?.arguments, {
        'identifier': 42,
        'origins': isEmpty,
        'source': null,
      });
    });
  });
}

class _AndroidController extends Fake implements AndroidWebViewController {
  @override
  int get webViewIdentifier => 42;
}
