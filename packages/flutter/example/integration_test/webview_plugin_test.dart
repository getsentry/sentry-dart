// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/app_config.dart' show exampleDsn;
import 'package:sentry_flutter_example/screens/webview_tracing_screen.dart';
import 'package:sentry_webview_flutter/sentry_webview_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'utils.dart';

// The browser SDK loads from Sentry's CDN. Opt in on devices with network access.
const _runLiveTests = bool.fromEnvironment('SENTRY_WEBVIEW_LIVE_TEST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryWebViewTracing', () {
    testWidgets(
      'replaces the trace and allowed hosts for the next navigation',
      (tester) async {
        await Sentry.init((o) {
          o.dsn = fakeDsn;
        });
        addTearDown(Sentry.close);
        final controller = WebViewController();
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        final hub = Sentry.currentHub;
        Future<bool> install(List<String> hosts) =>
            SentryWebViewTracing.addTracePropagation(
              controller,
              allowedHosts: hosts,
            );

        late Completer<Map<String, dynamic>> observed;
        await controller.addJavaScriptChannel(
          'PageResult',
          onMessageReceived: (message) {
            observed.complete(
              jsonDecode(message.message) as Map<String, dynamic>,
            );
          },
        );

        Future<Map<String, dynamic>> load(String host) async {
          observed = Completer();
          // The app-owned channel must survive every replacement. Read tags in
          // the first inline page script, as the browser SDK does on startup.
          await controller.loadHtmlString('''
<!doctype html><html><head><script>
const content = name => document.querySelector('meta[name="' + name + '"]')?.content;
const trace = content('sentry-trace') ?? null;
const baggage = content('baggage') ?? null;
</script></head><body>
<iframe srcdoc="<html></html>" onload="PageResult.postMessage(JSON.stringify({
  trace, baggage, frame: !!this.contentDocument.querySelector('meta[name=sentry-trace]')
}))"></iframe></body></html>
''', baseUrl: 'https://$host/');
          return observed.future.timeout(const Duration(seconds: 20));
        }

        if (Platform.isAndroid) {
          const host = MethodChannel('example.flutter.sentry.io');
          final supported = await host.invokeMethod<bool>(
            'supportsWebViewDocumentStart',
          );
          expect(supported, isNotNull);
          if (supported == false) {
            expect(await install(['first.example']), isFalse);
            expect((await load('first.example'))['trace'], isNull);
            return;
          }
        }

        final first = hub.scope.propagationContext.traceId;
        expect(await install(['first.example', 'second.example']), isTrue);
        final page = await load('first.example');
        expect(page['trace'], startsWith('$first-'));
        expect(page['baggage'], contains('sentry-trace_id=$first'));
        expect(page['frame'], isFalse);

        hub.generateNewTrace();
        final second = hub.scope.propagationContext.traceId;
        expect(second, isNot(first));
        expect(await install(['second.example']), isTrue);
        expect((await load('first.example'))['trace'], isNull);
        expect((await load('second.example'))['trace'], startsWith('$second-'));

        if (Platform.isIOS || Platform.isMacOS) {
          await controller.addJavaScriptChannel(
            'Temporary',
            onMessageReceived: (_) {},
          );
          await controller.removeJavaScriptChannel('Temporary');
          await controller.enableZoom(true);
          expect((await load('second.example'))['trace'], isNull);
          expect(await install(['second.example']), isTrue);
          expect(
            (await load('second.example'))['trace'],
            startsWith('$second-'),
          );
        }

        expect(await install([]), isFalse);
        expect((await load('second.example'))['trace'], isNull);
        expect(
          hub.options.sdk.integrations,
          contains('WebViewTracePropagation'),
        );
      },
    );

    testWidgets('skips a child document on an allowlisted HTTPS origin', (
      tester,
    ) async {
      await Sentry.init((o) => o.dsn = fakeDsn);
      addTearDown(Sentry.close);
      // Use a read-only resource on Sentry's CDN so the frame has a real HTTPS
      // document URL. A srcdoc frame alone would also fail the protocol check.
      final resource = Uri.parse(webViewExampleBrowserBundle['url']!);
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final observed = Completer<Map<String, dynamic>>();
      await controller.addJavaScriptChannel(
        'FrameResult',
        onMessageReceived: (message) {
          observed.complete(
            jsonDecode(message.message) as Map<String, dynamic>,
          );
        },
      );
      expect(
        await SentryWebViewTracing.addTracePropagation(
          controller,
          allowedHosts: [resource.host],
        ),
        isTrue,
      );
      await controller.loadHtmlString('''
<!doctype html><iframe src="$resource" onload="try {
  FrameResult.postMessage(JSON.stringify({
    topTrace: !!document.querySelector('meta[name=sentry-trace]'),
    url: this.contentDocument.URL,
    frameTrace: !!this.contentDocument.querySelector('meta[name=sentry-trace]')
  }));
} catch (error) { FrameResult.postMessage('{}'); }"></iframe>
''', baseUrl: '${resource.origin}/');
      expect(await observed.future.timeout(const Duration(seconds: 30)), {
        'topTrace': true,
        'url': resource.toString(),
        'frameTrace': false,
      });
    }, skip: !_runLiveTests);

    testWidgets(
      'browser pageload inherits a rejection and samples a fresh trace',
      (tester) async {
        await Sentry.init((o) {
          o.dsn = fakeDsn;
          o.tracesSampleRate = 0;
        });
        addTearDown(Sentry.close);
        final hub = Sentry.currentHub;
        final controller = WebViewController();
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        late Completer<void> loaded;
        await controller.setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!loaded.isCompleted) loaded.complete();
            },
          ),
        );
        Future<void> expectPageload(bool sampled) async {
          final expectedTrace = hub.scope.propagationContext.traceId.toString();
          expect(
            await SentryWebViewTracing.addTracePropagation(
              controller,
              allowedHosts: [webViewExampleHost],
            ),
            isTrue,
          );
          loaded = Completer();
          await controller.loadHtmlString(
            webViewExampleHtml(fakeDsn),
            baseUrl: 'https://$webViewExampleHost/',
          );
          await loaded.future.timeout(const Duration(seconds: 30));
          expect(
            await controller.runJavaScriptReturningResult(
              'window.pageTrace?.traceId === "$expectedTrace"',
            ),
            isTrue,
            reason: 'The browser pageload should inherit the Flutter trace ID.',
          );
          expect(
            await controller.runJavaScriptReturningResult(
              'window.pageTrace.sampled',
            ),
            sampled,
          );
        }

        hub.startSpanSync('sampled-out root', (_) {});
        expect(hub.scope.propagationContext.sampled, isFalse);
        await expectPageload(false);
        hub.generateNewTrace();
        expect(hub.scope.propagationContext.sampled, isNull);
        await expectPageload(true);
      },
      skip: !_runLiveTests,
    );

    testWidgets('sends a connected Flutter transaction and browser pageload', (
      tester,
    ) async {
      final platform = Platform.operatingSystem;
      await Sentry.init((o) {
        o.dsn = exampleDsn;
        o.environment = 'webview-example';
        o.tracesSampleRate = 1;
        o.traceLifecycle = SentryTraceLifecycle.static;
      });
      addTearDown(Sentry.close);
      final transaction = Sentry.startTransaction(
        'WebView sample ($platform)',
        'ui.load',
        bindToScope: true,
      );
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final loaded = Completer<void>();
      final flushed = Completer<String>();
      await controller.addJavaScriptChannel(
        'FlushResult',
        onMessageReceived: (message) => flushed.complete(message.message),
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!loaded.isCompleted) loaded.complete();
          },
        ),
      );
      try {
        expect(
          await SentryWebViewTracing.addTracePropagation(
            controller,
            allowedHosts: [webViewExampleHost],
          ),
          isTrue,
        );
        await controller.loadHtmlString(
          webViewExampleHtml(exampleDsn),
          baseUrl: 'https://$webViewExampleHost/$platform',
        );
        await loaded.future.timeout(const Duration(seconds: 30));
        final trace = transaction.toSentryTrace().traceId;
        expect(
          await controller.runJavaScriptReturningResult(
            'window.pageTrace?.traceId === "$trace" && window.pageTrace.sampled',
          ),
          isTrue,
        );
        await controller.runJavaScript("""
          Sentry.getActiveSpan()?.end();
          Sentry.flush(10000).then(ok => FlushResult.postMessage(String(ok)));
        """);
        expect(
          await flushed.future.timeout(const Duration(seconds: 15)),
          'true',
        );
        tester.printToConsole(
          'WebView sample $platform: https://sentry-sdks.sentry.io/explore/traces/trace/$trace/',
        );
      } finally {
        await transaction.finish();
      }
    }, skip: !_runLiveTests);
  }, skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
}
