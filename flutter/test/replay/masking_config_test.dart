import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/masking_config.dart';

import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('will not mask if there are no rules', (tester) async {
    final sut = SentryMaskingConfig([]);
    final element = await pumpTestElement(tester);
    expect(sut.rules, isEmpty);
    expect(sut.length, 0);
    expect(sut.shouldMask(element, element.widget), isFalse);
  });

  for (final value in [MaskingDecision.mask, MaskingDecision.unmask]) {
    group('$SentryMaskingConstantRule($value)', () {
      testWidgets('will mask widget by type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Image>();
        expect(sut.shouldMask(element, element.widget),
            value == MaskingDecision.mask);
      });

      testWidgets('will mask subtype widget by type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<CustomImageWidget>();
        expect(sut.shouldMask(element, element.widget),
            value == MaskingDecision.mask);
      });

      testWidgets('will not mask widget of a different type', (tester) async {
        final sut =
            SentryMaskingConfig([SentryMaskingConstantRule<Image>(value)]);
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Text>();
        expect(sut.shouldMask(element, element.widget), false);
      }, skip: value == MaskingDecision.unmask);
    });
  }

  group('$SentryMaskingCustomRule', () {
    testWidgets('only called for specified type', (tester) async {
      final called = <Type, int>{};
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>((e, w) {
          called[w.runtimeType] = (called[w.runtimeType] ?? 0) + 1;
          return MaskingDecision.continueProcessing;
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

    testWidgets('stops iteration on the first "mask" rule', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => MaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>((e, w) => MaskingDecision.mask),
        SentryMaskingCustomRule<Image>((e, w) => fail('should not be called'))
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget), isTrue);
    });

    testWidgets('stops iteration on first "unmask" rule', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => MaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>((e, w) => MaskingDecision.unmask),
        SentryMaskingCustomRule<Image>((e, w) => fail('should not be called'))
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget), isFalse);
    });

    testWidgets('retuns false if no rule matches', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => MaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>(
            (e, w) => MaskingDecision.continueProcessing),
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget), isFalse);
    });
  });

  group('$SentryReplayOptions.buildMaskingConfig()', () {
    List<String> stringRules(SentryReplayOptions options) {
      final config = options.buildMaskingConfig();
      return config.rules
          .map((rule) => rule.toString())
          .map((str) => str.replaceAll(RegExp(r'@[0-9]+'), '@<id>'))
          .toList();
    }

    test('defaults', () {
      final sut = SentryReplayOptions();
      expect(stringRules(sut), [
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => MaskingDecision from Function \'_maskImagesExceptAssets@<id>\': static.)',
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)'
      ]);
    });

    test('maskAllImages=true & maskAssetImages=true', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = true;
      expect(stringRules(sut), [
        '$SentryMaskingConstantRule<$Image>(mask)',
      ]);
    });

    test('maskAllImages=true & maskAssetImages=false', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = false;
      expect(stringRules(sut), [
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => MaskingDecision from Function \'_maskImagesExceptAssets@<id>\': static.)',
      ]);
    });

    test('maskAllText=true', () {
      final sut = SentryReplayOptions()
        ..maskAllText = true
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(stringRules(sut), [
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)'
      ]);
    });

    test('maskAllText=false', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(stringRules(sut), isEmpty);
    });

    group('user rules', () {
      final defaultRules = [
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => MaskingDecision from Function \'_maskImagesExceptAssets@<id>\': static.)',
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)'
      ];
      test('mask() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.mask<Image>();
        expect(stringRules(sut),
            ['$SentryMaskingConstantRule<$Image>(mask)', ...defaultRules]);
      });
      test('unmask() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.unmask<Image>();
        expect(stringRules(sut),
            ['$SentryMaskingConstantRule<$Image>(unmask)', ...defaultRules]);
      });
      test('are ordered in the call order', () {
        var sut = SentryReplayOptions();
        sut.mask<Image>();
        sut.unmask<Image>();
        expect(stringRules(sut), [
          '$SentryMaskingConstantRule<$Image>(mask)',
          '$SentryMaskingConstantRule<$Image>(unmask)',
          ...defaultRules
        ]);
        sut = SentryReplayOptions();
        sut.unmask<Image>();
        sut.mask<Image>();
        expect(stringRules(sut), [
          '$SentryMaskingConstantRule<$Image>(unmask)',
          '$SentryMaskingConstantRule<$Image>(mask)',
          ...defaultRules
        ]);
        sut = SentryReplayOptions();
        sut.unmask<Image>();
        sut.maskCallback((_, Image widget) => MaskingDecision.mask);
        sut.mask<Image>();
        expect(stringRules(sut), [
          '$SentryMaskingConstantRule<$Image>(unmask)',
          '$SentryMaskingCustomRule<$Image>(Closure: ($Element, $Image) => $MaskingDecision)',
          '$SentryMaskingConstantRule<$Image>(mask)',
          ...defaultRules
        ]);
      });
      test('maskCallback() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.maskCallback((_, Image widget) => MaskingDecision.mask);
        expect(stringRules(sut), [
          '$SentryMaskingCustomRule<$Image>(Closure: ($Element, $Image) => $MaskingDecision)',
          ...defaultRules
        ]);
      });
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
