import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/widgets_binding_observer.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  group('WidgetsBindingObserver', () {
    late SentryFlutterOptions flutterTrackingEnabledOptions;
    late SentryFlutterOptions flutterTrackingDisabledOptions;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      flutterTrackingEnabledOptions = SentryFlutterOptions()
        ..bindingUtils = TestBindingWrapper();
      flutterTrackingEnabledOptions.useFlutterBreadcrumbTracking();

      flutterTrackingDisabledOptions = SentryFlutterOptions()
        ..bindingUtils = TestBindingWrapper();
      flutterTrackingDisabledOptions.useNativeBreadcrumbTracking();
    });

    testWidgets('memory pressure breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = flutterTrackingEnabledOptions.bindingUtils.instance;
      instance!.addObserver(observer);

      final message = const JSONMessageCodec()
          .encodeMessage(<String, dynamic>{'type': 'memoryPressure'});

      await instance.defaultBinaryMessenger
          // ignore: deprecated_member_use
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

      instance.removeObserver(observer);
    });

    testWidgets('disable memory pressure breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      final instance = flutterTrackingDisabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      final message = const JSONMessageCodec()
          .encodeMessage(<String, dynamic>{'type': 'memoryPressure'});

      await instance.defaultBinaryMessenger
          // ignore: deprecated_member_use
          .handlePlatformMessage('flutter/system', message, (_) {});

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('lifecycle breadcrumbs', (WidgetTester tester) async {
      Future<void> sendLifecycle(String event) async {
        final messenger = TestWidgetsFlutterBinding.ensureInitialized()
            .defaultBinaryMessenger;
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
      final instance = flutterTrackingEnabledOptions.bindingUtils.instance;
      instance!.addObserver(observer);

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
      await sendLifecycle('paused');
      await sendLifecycle('detached');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'app.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.data, mapForLifecycle('detached'));
      expect(breadcrumb.level, SentryLevel.info);

      instance.removeObserver(observer);
    });

    testWidgets('disable lifecycle breadcrumbs', (WidgetTester tester) async {
      Future<void> sendLifecycle(String event) async {
        final messenger = TestWidgetsFlutterBinding.ensureInitialized()
            .defaultBinaryMessenger;
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
      final instance = flutterTrackingDisabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      await sendLifecycle('paused');

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('metrics changed breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = tester.binding;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      const newWidth = 123.0;
      const newHeight = 456.0;
      // ignore: deprecated_member_use
      window.physicalSizeTestValue = Size(newWidth, newHeight);

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message, 'Screen size changed');
      expect(breadcrumb.category, 'device.screen');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.data, <String, dynamic>{
        // ignore: deprecated_member_use
        'new_pixel_ratio': window.devicePixelRatio,
        'new_height': newHeight,
        'new_width': newWidth,
      });

      instance.removeObserver(observer);
    });

    testWidgets('only unique metrics emit events', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = tester.binding;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      // ignore: deprecated_member_use
      window.physicalSizeTestValue = window.physicalSize;

      const newPixelRatio = 1.618;
      // ignore: deprecated_member_use
      window.devicePixelRatioTestValue = newPixelRatio;

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message, 'Screen size changed');
      expect(breadcrumb.category, 'device.screen');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.data, <String, dynamic>{
        'new_pixel_ratio': newPixelRatio,
        // ignore: deprecated_member_use
        'new_height': window.physicalSize.height,
        // ignore: deprecated_member_use
        'new_width': window.physicalSize.width,
      });

      instance.removeObserver(observer);
    });

    testWidgets('no breadcrumb on unrelated metrics changes',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = tester.binding;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      // ignore: deprecated_member_use
      window.viewInsetsTestValue = WindowPadding.zero;

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('disable metrics changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      final instance = flutterTrackingDisabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      window.onMetricsChanged!();

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('platform brightness breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = flutterTrackingEnabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      window.onPlatformBrightnessChanged!();

      // ignore: deprecated_member_use
      final brightness = instance.window.platformBrightness;
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

      instance.removeObserver(observer);
    });

    testWidgets('disable platform brightness breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingDisabledOptions,
      );
      final instance = flutterTrackingDisabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      window.onPlatformBrightnessChanged!();

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('text scale factor brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = flutterTrackingEnabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      window.onTextScaleFactorChanged!();

      // ignore: deprecated_member_use
      final newTextScaleFactor = instance.window.textScaleFactor;

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

      instance.removeObserver(observer);
    });

    testWidgets('disable text scale factor brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
          hub: hub, options: flutterTrackingDisabledOptions);
      final instance = flutterTrackingDisabledOptions.bindingUtils.instance!;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      window.onTextScaleFactorChanged!();

      verifyNever(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('debouncing didChangeMetrics with 100ms delay',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = tester.binding;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      // ignore: deprecated_member_use
      window.physicalSizeTestValue = window.physicalSize;

      const newPixelRatio = 1.7;
      // ignore: deprecated_member_use
      window.devicePixelRatioTestValue = newPixelRatio;

      verifyNever(hub.addBreadcrumb(captureAny));

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      verify(hub.addBreadcrumb(captureAny));

      instance.removeObserver(observer);
    });

    testWidgets('debouncing: didChangeMetrics is called only once in 100ms',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(
        hub: hub,
        options: flutterTrackingEnabledOptions,
      );
      final instance = tester.binding;
      instance.addObserver(observer);

      // ignore: deprecated_member_use
      final window = instance.window;

      // ignore: deprecated_member_use
      window.physicalSizeTestValue = window.physicalSize;

      // ignore: deprecated_member_use
      window.devicePixelRatioTestValue = 2.1;
      // ignore: deprecated_member_use
      window.devicePixelRatioTestValue = 2.2;
      // ignore: deprecated_member_use
      window.devicePixelRatioTestValue = 2.3;

      verifyNever(hub.addBreadcrumb(captureAny));

      // waiting for debouncing with 100ms added https://github.com/getsentry/sentry-dart/issues/400
      await tester.pump(Duration(milliseconds: 150));

      verify(hub.addBreadcrumb(captureAny)).called(1);

      instance.removeObserver(observer);
    });
  });
}
