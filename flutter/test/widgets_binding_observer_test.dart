import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';
import 'package:sentry_flutter/src/widgets_binding_observer.dart';

import 'mocks.mocks.dart';

void main() {
  group('WidgetsBindingObserver', () {
    late SentryFlutterOptions flutterTrackingEnabledOptions;
    late SentryFlutterOptions flutterTrackingDisabledOptions;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();

      flutterTrackingEnabledOptions = SentryFlutterOptions();
      flutterTrackingEnabledOptions.useFlutterBreadcrumbTracking();

      flutterTrackingDisabledOptions = SentryFlutterOptions();
      flutterTrackingDisabledOptions.useNativeBreadcrumbTracking();
    });

    testWidgets('memory pressure breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final message = const JSONMessageCodec()
          .encodeMessage(<String, dynamic>{'type': 'memoryPressure'});

      await WidgetsBinding.instance!.defaultBinaryMessenger
          .handlePlatformMessage('flutter/system', message, (_) {});

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(
        breadcrumb.message,
        'App had memory pressure. This indicates that the operating system '
        'would like applications to release caches to free up more memory.',
      );

      expect(breadcrumb.level, SentryLevel.warning);
      expect(breadcrumb.type, 'system');
      expect(breadcrumb.category, 'device.event');

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('disable memory pressure breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final message = const JSONMessageCodec()
          .encodeMessage(<String, dynamic>{'type': 'memoryPressure'});

      await WidgetsBinding.instance!.defaultBinaryMessenger
          .handlePlatformMessage('flutter/system', message, (_) {});

      verifyNever(hub.addBreadcrumb(captureAny));

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('lifecycle breadcrumbs', (WidgetTester tester) async {
      Future<void> sendLifecycle(String event) async {
        final messenger = ServicesBinding.instance!.defaultBinaryMessenger;
        final message =
            const StringCodec().encodeMessage('AppLifecycleState.$event');
        await messenger.handlePlatformMessage(
            'flutter/lifecycle', message, (_) {});
      }

      Map<String, String> mapForLifecycle(String state) {
        return <String, String>{'state': state};
      }

      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      // paused lifecycle event
      await sendLifecycle('paused');

      var breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'app.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.data, mapForLifecycle('paused'));
      expect(breadcrumb.level, SentryLevel.info);

      // resumed lifecycle event
      await sendLifecycle('resumed');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'app.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.data, mapForLifecycle('resumed'));
      expect(breadcrumb.level, SentryLevel.info);

      // inactive lifecycle event
      await sendLifecycle('inactive');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'app.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.data, mapForLifecycle('inactive'));
      expect(breadcrumb.level, SentryLevel.info);

      // detached lifecycle event
      await sendLifecycle('detached');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'app.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.data, mapForLifecycle('detached'));
      expect(breadcrumb.level, SentryLevel.info);

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('disable lifecycle breadcrumbs', (WidgetTester tester) async {
      Future<void> sendLifecycle(String event) async {
        final messenger = ServicesBinding.instance!.defaultBinaryMessenger;
        final message =
            const StringCodec().encodeMessage('AppLifecycleState.$event');
        await messenger.handlePlatformMessage(
            'flutter/lifecycle', message, (_) {});
      }

      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      await sendLifecycle('paused');

      verifyNever(hub.addBreadcrumb(captureAny));

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('metrics changed breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onMetricsChanged!();

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message, 'Screen size changed');
      expect(breadcrumb.category, 'device.screen');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.data, <String, dynamic>{
        'new_pixel_ratio': window.devicePixelRatio,
        'new_height': window.physicalSize.height,
        'new_width': window.physicalSize.width,
      });

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('disable metrics changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onMetricsChanged!();

      verifyNever(hub.addBreadcrumb(captureAny));

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('platform brightness breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onPlatformBrightnessChanged!();

      final brightness = WidgetsBinding.instance!.window.platformBrightness;
      final brightnessDescription =
          brightness == Brightness.dark ? 'dark' : 'light';

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message,
          'Platform brightness was changed to $brightnessDescription.');

      expect(breadcrumb.category, 'device.event');
      expect(breadcrumb.type, 'system');
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.data, <String, String>{
        'action': 'BRIGHTNESS_CHANGED_TO_${brightnessDescription.toUpperCase()}'
      });

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('disable platform brightness breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onPlatformBrightnessChanged!();

      verifyNever(hub.addBreadcrumb(captureAny));

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('text scale factor brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onTextScaleFactorChanged!();

      final newTextScaleFactor = WidgetsBinding.instance!.window.textScaleFactor;

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message,
          'Text scale factor changed to $newTextScaleFactor.');
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.type, 'system');
      expect(breadcrumb.category, 'device.event');
      expect(breadcrumb.data, <String, String>{
        'action': 'TEXT_SCALE_CHANGED_TO_$newTextScaleFactor'
      });

      WidgetsBinding.instance!.removeObserver(observer);
    });

    testWidgets('disable text scale factor brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
          hub: hub, options: flutterTrackingDisabledOptions);
      WidgetsBinding.instance!.addObserver(observer);

      final window = WidgetsBinding.instance!.window;

      window.onTextScaleFactorChanged!();

      verifyNever(hub.addBreadcrumb(captureAny));

      WidgetsBinding.instance!.removeObserver(observer);
    });
  });
}
