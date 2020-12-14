import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

void main() {
  group('SentryFlutterOptions', () {
    testWidgets('auto breadcrumb tracking', (WidgetTester tester) async {
      final options = SentryFlutterOptions();
      options.configureBreadcrumbTrackingForPlatform(TargetPlatform.android);

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);

      options.configureBreadcrumbTrackingForPlatform(TargetPlatform.iOS);

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);

      // for all other platform the inverse is true
      final platforms = [
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ];

      for (final platform in platforms) {
        options.configureBreadcrumbTrackingForPlatform(platform);

        expect(options.enableAppLifecycleBreadcrumbs, isTrue);
        expect(options.enableWindowMetricBreadcrumbs, isTrue);
        expect(options.enableBrightnessChangeBreadcrumbs, isTrue);
        expect(options.enableTextScaleChangeBreadcrumbs, isTrue);
        expect(options.enableMemoryPressureBreadcrumbs, isTrue);
        expect(options.enableAutoNativeBreadcrumbs, isFalse);
      }
    });

    testWidgets('useFlutterBreadcrumbTracking', (WidgetTester tester) async {
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
