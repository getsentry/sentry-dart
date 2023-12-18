import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.dart';

void main() {
  group('SentryFlutterOptions', () {
    testWidgets('auto breadcrumb tracking: has native integration',
        (WidgetTester tester) async {
      final options = SentryFlutterOptions(
          checker: MockPlatformChecker(hasNativeIntegration: true));

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);
    });

    testWidgets('auto breadcrumb tracking: without native integration',
        (WidgetTester tester) async {
      final options = SentryFlutterOptions(
          checker: MockPlatformChecker(hasNativeIntegration: false));

      expect(options.enableAppLifecycleBreadcrumbs, isTrue);
      expect(options.enableWindowMetricBreadcrumbs, isTrue);
      expect(options.enableBrightnessChangeBreadcrumbs, isTrue);
      expect(options.enableTextScaleChangeBreadcrumbs, isTrue);
      expect(options.enableMemoryPressureBreadcrumbs, isTrue);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
    });

    testWidgets('useNativeBreadcrumbTracking', (WidgetTester tester) async {
      final options = SentryFlutterOptions();
      options.useNativeBreadcrumbTracking();

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);
    });

    testWidgets('useFlutterBreadcrumbTracking', (WidgetTester tester) async {
      final options = SentryFlutterOptions();
      options.useFlutterBreadcrumbTracking();

      expect(options.enableAppLifecycleBreadcrumbs, isTrue);
      expect(options.enableWindowMetricBreadcrumbs, isTrue);
      expect(options.enableBrightnessChangeBreadcrumbs, isTrue);
      expect(options.enableTextScaleChangeBreadcrumbs, isTrue);
      expect(options.enableMemoryPressureBreadcrumbs, isTrue);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
    });
  });
}
