import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/widget_filter.dart';

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
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 2);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactText: false);
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactText: true);
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 100, 100));
      expect(sut.items.length, 1);
    });
  });

  group('redact images', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 2);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactImages: false);
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactImages: true);
      final element = await _getTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 500, 100));
      expect(sut.items.length, 1);
    });
  });
}

Future<Element> _getTestElement(WidgetTester tester) async {
  final newImage = () =>
      Image.memory(Uint8List.fromList(_sampleBitmap), width: 1, height: 1);
  await tester.pumpWidget(MaterialApp(
    home: SingleChildScrollView(
      child: Visibility(
          visible: true,
          child: Opacity(
              opacity: 0.5,
              child: Column(
                children: <Widget>[
                  newImage(),
                  const Padding(
                    padding: EdgeInsets.all(15),
                    child: Center(child: Text('Centered text')),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Button title'),
                  ),
                  newImage(),
                  // Invisible widgets won't be obscured.
                  Visibility(visible: false, child: Text('Invisible text')),
                  Visibility(visible: false, child: newImage()),
                  Opacity(opacity: 0, child: Text('Invisible text')),
                  Opacity(opacity: 0, child: newImage()),
                  Offstage(offstage: true, child: Text('Offstage text')),
                  Offstage(offstage: true, child: newImage()),
                ],
              ))),
    ),
  ));
  return TestWidgetsFlutterBinding.instance.rootElement!;
}

const _sampleBitmap = [
  66, 77, 142, 0, 0, 0, 0, 0, 0, 0, 138, 0, 0, 0, 124, 0, 0, 0, 1, 0, 0, 0,
  255, 255, 255, 255, 1, 0, 32, 0, 3, 0, 0, 0, 4, 0, 0, 0, 19, 11, 0, 0, 19,
  11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 0,
  0, 0, 0, 255, 66, 71, 82, 115, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 135,
  135, 135, 255,
  // This comment prevents dartfmt from splitting the list to many more lines.
];
