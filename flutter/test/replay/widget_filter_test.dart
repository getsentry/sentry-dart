import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/widget_filter.dart';

import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const defaultBounds = Rect.fromLTRB(0, 0, 1000, 1000);

  final createSut =
      ({bool redactImages = false, bool redactText = false}) => WidgetFilter(
            logger: (level, message, {exception, logger, stackTrace}) {},
            redactImages: redactImages,
            redactText: redactText,
          );

  group('redact text', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactText: true);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 2);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactText: false);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactText: true);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 100, 100));
      expect(sut.items.length, 1);
    });
  });

  group('redact images', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 2);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactImages: false);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactImages: true);
      final element = await getTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 500, 100));
      expect(sut.items.length, 1);
    });
  });
}
