@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:sentry/src/event_processor/enricher/flutter_runtime.dart';
import 'package:sentry_flutter/src/sentry_privacy_options.dart';

void main() {
  group('shouldAddSensitiveContentRule', () {
    test('returns true for supported versions (>= 3.33)', () {
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(3, 33)),
          isTrue);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(3, 34)),
          isTrue);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(4, 0)),
          isTrue);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(5, 0)),
          isTrue);
    });

    test('returns false for unsupported versions (< 3.33)', () {
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(3, 32)),
          isFalse);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(3, 0)),
          isFalse);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(2, 99)),
          isFalse);
      expect(
          shouldAddSensitiveContentRule(const FlutterVersionComponents(1, 0)),
          isFalse);
    });

    test('returns false for null components (malformed version)', () {
      expect(shouldAddSensitiveContentRule(null), isFalse);
    });
  });

  group('isSensitiveContentWidget', () {
    test('returns false for standard widgets without sensitivity property', () {
      expect(isSensitiveContentWidget(Container()), isFalse);
      expect(isSensitiveContentWidget(const Text('test')), isFalse);
      expect(isSensitiveContentWidget(const SizedBox()), isFalse);
      expect(isSensitiveContentWidget(const Placeholder()), isFalse);
    });

    test('returns true for widget with sensitivity Enum property', () {
      expect(isSensitiveContentWidget(const _MockSensitiveWidget()), isTrue);
    });

    test('returns false for widget with null sensitivity property', () {
      // Widget with a sensitivity property that returns null.
      // The property exists but is not an Enum, so it should return false.
      // This behavior is consistent in both debug and release modes.
      expect(isSensitiveContentWidget(const _WidgetWithNullSensitivity()),
          isFalse);
    });

    test('returns false for widget with non-Enum sensitivity property', () {
      expect(isSensitiveContentWidget(const _WidgetWithStringSensitivity()),
          isFalse);
    });
  });
}

/// Mock widget that has a `sensitivity` property like SensitiveContent.
class _MockSensitiveWidget extends StatelessWidget {
  const _MockSensitiveWidget();

  // Mimics the SensitiveContent widget's sensitivity property
  _MockSensitivity get sensitivity => _MockSensitivity.high;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Mock enum to mimic the Sensitivity enum from Flutter's SensitiveContent.
enum _MockSensitivity { high, medium, low }

/// Widget with null sensitivity (edge case).
class _WidgetWithNullSensitivity extends StatelessWidget {
  const _WidgetWithNullSensitivity();

  Object? get sensitivity => null;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Widget with non-Enum sensitivity (edge case).
class _WidgetWithStringSensitivity extends StatelessWidget {
  const _WidgetWithStringSensitivity();

  String get sensitivity => 'high';

  @override
  Widget build(BuildContext context) => const SizedBox();
}
