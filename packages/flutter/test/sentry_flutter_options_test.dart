import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'mocks.dart';

void main() {
  group('SentryFlutterOptions', () {
    testWidgets('auto breadcrumb tracking: has native integration',
        (WidgetTester tester) async {
      final options = defaultTestOptions();

      expect(options.enableAppLifecycleBreadcrumbs, isFalse);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isTrue);
    });

    testWidgets('auto breadcrumb tracking: without native integration',
        (WidgetTester tester) async {
      final options = defaultTestOptions(platform: MockPlatform.fuchsia());

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

    testWidgets('enableTombstone defaults to false',
        (WidgetTester tester) async {
      final options = defaultTestOptions();

      expect(options.enableTombstone, isFalse);
    });

    test('addUserInteractionWidget adds sdk feature', () {
      final options = defaultTestOptions();

      options.addUserInteractionWidget<Text>('Text');

      expect(options.sdk.features, contains('userInteractionWidgetTypes'));
    });

    test('addUserInteractionLabel adds sdk feature', () {
      final options = defaultTestOptions();

      options.addUserInteractionLabel<Text>((widget) => widget.data);

      expect(options.sdk.features, contains('userInteractionWidgetTypes'));
    });

    test('addUserInteractionWidget throws AssertionError for Widget type', () {
      final options = defaultTestOptions();

      expect(
        () => options.addUserInteractionWidget<Widget>('Widget'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('addUserInteractionLabel throws AssertionError for Widget type', () {
      final options = defaultTestOptions();

      expect(
        () => options.addUserInteractionLabel<Widget>((_) => null),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
