import 'package:flutter_test/flutter_test.dart';

import 'mocks.dart';

void main() {
  group('SentryFlutterOptions', () {
    testWidgets('auto breadcrumb tracking: has native integration',
        (WidgetTester tester) async {
      final options =
          defaultTestOptions(MockPlatformChecker(hasNativeIntegration: true));

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);
    });

    testWidgets('auto breadcrumb tracking: without native integration',
        (WidgetTester tester) async {
      final options =
          defaultTestOptions(MockPlatformChecker(hasNativeIntegration: false));

      expect(options.enableAppLifecycleBreadcrumbs, isTrue);
      expect(options.enableWindowMetricBreadcrumbs, isTrue);
      expect(options.enableBrightnessChangeBreadcrumbs, isTrue);
      expect(options.enableTextScaleChangeBreadcrumbs, isTrue);
      expect(options.enableMemoryPressureBreadcrumbs, isTrue);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
    });

    testWidgets('useNativeBreadcrumbTracking', (WidgetTester tester) async {
      final options = defaultTestOptions();
      options.useNativeBreadcrumbTracking();

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);
    });

    testWidgets('useFlutterBreadcrumbTracking', (WidgetTester tester) async {
      final options = defaultTestOptions();
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
