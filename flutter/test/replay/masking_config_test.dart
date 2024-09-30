import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/masking_config.dart';

import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('will not mask if there are no rules', (tester) async {
    final sut = SentryMaskingConfig([]);
    final element = await pumpTestElement(tester);
    expect(sut.rules, isEmpty);
    expect(sut.shouldMask(element, element.widget), isFalse);
  });

  for (final value in [true, false]) {
    group('$SentryMaskingConstantRule($value)', () {
      testWidgets('will mask widget by type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Image>();
        expect(sut.shouldMask(element, element.widget), value);
      });

      testWidgets('will mask subtype widget by type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<CustomImageWidget>();
        expect(sut.shouldMask(element, element.widget), value);
      });

      testWidgets('will not mask widget of a different type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Text>();
        expect(sut.shouldMask(element, element.widget), !value);
      }, skip: !value);
    });
  }

  group('$SentryMaskingCustomRule', () {
    testWidgets('only called for specified type', (tester) async {
      final called = <Type, int>{};
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>((e, w) {
          called[w.runtimeType] = (called[w.runtimeType] ?? 0) + 1;
          return false;
        })
      ]);
      final rootElement = await pumpTestElement(tester);
      for (final element in rootElement.findAllChildren()) {
        expect(sut.shouldMask(element, element.widget), isFalse);
      }
      // Note: there are actually 5 Image widgets in the tree but when it's
      // inside an `Visibility(visible: false)`, it won't be visited.
      expect(called, {Image: 4, CustomImageWidget: 1});
    });

    testWidgets('stops iteration on first truthy rule', (tester) async {
      var called = 0;
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>((e, w) => ++called == -1),
        SentryMaskingCustomRule<Image>((e, w) => ++called == 2),
        SentryMaskingCustomRule<Image>((e, w) => fail('should not be called'))
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget), isTrue);
    });

    testWidgets('retuns false if no rule matches', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>((e, w) => false),
        SentryMaskingCustomRule<Image>((e, w) => false),
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget), isFalse);
    });
  });
}

extension on Element {
  Element findFirstOfType<T>() {
    late Element result;
    late void Function(Element) visitor;
    visitor = (Element element) {
      if (element.widget is T) {
        result = element;
      } else {
        element.visitChildElements(visitor);
      }
    };
    visitChildren((visitor));
    assert(result.widget is T);
    return result;
  }

  List<Element> findAllChildren() {
    final result = <Element>[];
    late void Function(Element) visitor;
    visitor = (Element element) {
      result.add(element);
      element.visitChildElements(visitor);
    };
    visitChildren((visitor));
    return result;
  }
}
