import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/widgets_binding_observer.dart';

import 'mocks.dart';

void main() {
  group('WidgetsBindingObserver', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('memory pressure breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(hub: hub);
      WidgetsBinding.instance.addObserver(observer);

      final ByteData message = const JSONMessageCodec()
          .encodeMessage(<String, dynamic>{'type': 'memoryPressure'});

      await WidgetsBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('flutter/system', message, (_) {});

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(
        breadcrumb.message,
        'App had memory pressure. This indicates that the operating system '
        'would like applications to release caches to free up more memory.',
      );

      expect(
        breadcrumb.level,
        SentryLevel.warning,
      );
      WidgetsBinding.instance.removeObserver(observer);
    });

    testWidgets('lifecycle breadcrumbs', (WidgetTester tester) async {
      Future<void> sendLifecycle(String event) async {
        final messenger = ServicesBinding.instance.defaultBinaryMessenger;
        final message =
            const StringCodec().encodeMessage('AppLifecycleState.$event');
        await messenger.handlePlatformMessage(
            'flutter/lifecycle', message, (_) {});
      }

      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(hub: hub);
      WidgetsBinding.instance.addObserver(observer);

      // paused lifecycle event
      sendLifecycle('paused');

      var breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'ui.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.message, 'paused');

      // resumed lifecycle event
      sendLifecycle('resumed');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'ui.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.message, 'resumed');

      // inactive lifecycle event
      sendLifecycle('inactive');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'ui.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.message, 'inactive');

      // detached lifecycle event
      sendLifecycle('detached');

      breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.last as Breadcrumb;
      expect(breadcrumb.category, 'ui.lifecycle');
      expect(breadcrumb.type, 'navigation');
      expect(breadcrumb.message, 'detached');

      WidgetsBinding.instance.removeObserver(observer);
    });

    testWidgets('metrics changed breadcrumb', (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(hub: hub);
      WidgetsBinding.instance.addObserver(observer);

      final window = WidgetsBinding.instance.window;

      window.onMetricsChanged();

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(breadcrumb.message, 'Screen sized changed');

      expect(breadcrumb.category, 'ui.lifecycle');

      expect(breadcrumb.data, <String, dynamic>{
        'new_pixel_ratio': window.devicePixelRatio,
        'new_height': window.physicalSize.height,
        'new_width': window.physicalSize.width,
      });
      WidgetsBinding.instance.removeObserver(observer);
    });

    testWidgets('platform brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(hub: hub);
      WidgetsBinding.instance.addObserver(observer);

      final window = WidgetsBinding.instance.window;

      window.onPlatformBrightnessChanged();

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(
        breadcrumb.message,
        'Platform brightness was changed to light.',
      );

      expect(breadcrumb.category, 'ui.lifecycle');

      WidgetsBinding.instance.removeObserver(observer);
    });

    testWidgets('text scale factor brightness changed breadcrumb',
        (WidgetTester tester) async {
      final hub = MockHub();

      final observer = SentryWidgetsBindingObserver(hub: hub);
      WidgetsBinding.instance.addObserver(observer);

      final window = WidgetsBinding.instance.window;

      window.onTextScaleFactorChanged();

      final breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;

      expect(
        breadcrumb.message,
        'Text scale factor changed to 1.0.',
      );

      expect(breadcrumb.category, 'ui');

      WidgetsBinding.instance.removeObserver(observer);
    });
  });
}
