import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/masking_config.dart';

import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final alwaysEnabledRules = [
    '$SentryMaskingConstantRule<$SentryMask>(mask)',
    '$SentryMaskingConstantRule<$SentryUnmask>(unmask)',
  ];

  testWidgets('will not mask if there are no rules', (tester) async {
    final sut = SentryMaskingConfig([]);
    final element = await pumpTestElement(tester);
    expect(sut.rules, isEmpty);
    expect(sut.length, 0);
    expect(sut.shouldMask(element, element.widget),
        SentryMaskingDecision.continueProcessing);
  });

  for (final value in [
    SentryMaskingDecision.mask,
    SentryMaskingDecision.unmask
  ]) {
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
        expect(sut.shouldMask(element, element.widget),
            SentryMaskingDecision.continueProcessing);
      }, skip: value == SentryMaskingDecision.unmask);
    });
  }

  group('$SentryMaskingCustomRule', () {
    testWidgets('only called for specified type', (tester) async {
      final called = <Type, int>{};
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>((e, w) {
          called[w.runtimeType] = (called[w.runtimeType] ?? 0) + 1;
          return SentryMaskingDecision.continueProcessing;
        })
      ]);
      final rootElement = await pumpTestElement(tester);
      for (final element in rootElement.findAllChildren()) {
        expect(sut.shouldMask(element, element.widget),
            SentryMaskingDecision.continueProcessing);
      }
      // Note: there are actually 5 Image widgets in the tree but when it's
      // inside an `Visibility(visible: false)`, it won't be visited.
      expect(called, {Image: 4, CustomImageWidget: 1});
    });

    testWidgets('stops iteration on the first "mask" rule', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => SentryMaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>((e, w) => SentryMaskingDecision.mask),
        SentryMaskingCustomRule<Image>((e, w) => fail('should not be called'))
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(
          sut.shouldMask(element, element.widget), SentryMaskingDecision.mask);
    });

    testWidgets('stops iteration on first "unmask" rule', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => SentryMaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>((e, w) => SentryMaskingDecision.unmask),
        SentryMaskingCustomRule<Image>((e, w) => fail('should not be called'))
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget),
          SentryMaskingDecision.unmask);
    });

    testWidgets('retuns false if no rule matches', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
            (e, w) => SentryMaskingDecision.continueProcessing),
        SentryMaskingCustomRule<Image>(
            (e, w) => SentryMaskingDecision.continueProcessing),
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget),
          SentryMaskingDecision.continueProcessing);
    });
  });

  group('$SentryReplayOptions.buildMaskingConfig()', () {
    List<String> rulesAsStrings(SentryReplayOptions options) {
      final config = options.buildMaskingConfig();
      return config.rules
          .map((rule) => rule.toString())
          // These normalize the string on VM & js & wasm:
          .map((str) => str.replaceAll(
              RegExp(
                  r"SentryMaskingDecision from:? [fF]unction '?_maskImagesExceptAssets[@(].*",
                  dotAll: true),
              'SentryMaskingDecision)'))
          .map((str) => str.replaceAll(
              ' from: (element, widget) => masking_config.SentryMaskingDecision.mask',
              ''))
          .toList();
    }

    test('defaults', () {
      final sut = SentryReplayOptions();
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => SentryMaskingDecision)',
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)',
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ]);
    });

    test('maskAllImages=true & maskAssetImages=true', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = true;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        '$SentryMaskingConstantRule<$Image>(mask)',
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ]);
    });

    test('maskAllImages=true & maskAssetImages=false', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => SentryMaskingDecision)',
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ]);
    });

    test('maskAllText=true', () {
      final sut = SentryReplayOptions()
        ..maskAllText = true
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)',
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ]);
    });

    test('maskAllText=false', () {
      final sut = SentryReplayOptions()
        ..maskAllText = false
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ]);
    });

    group('user rules', () {
      final defaultRules = [
        ...alwaysEnabledRules,
        '$SentryMaskingCustomRule<$Image>(Closure: (Element, Widget) => SentryMaskingDecision)',
        '$SentryMaskingConstantRule<$Text>(mask)',
        '$SentryMaskingConstantRule<$EditableText>(mask)',
        '$SentryMaskingCustomRule<$Widget>(Closure: ($Element, $Widget) => $SentryMaskingDecision)'
      ];
      test('mask() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.mask<Image>();
        expect(rulesAsStrings(sut),
            ['$SentryMaskingConstantRule<$Image>(mask)', ...defaultRules]);
      });
      test('unmask() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.unmask<Image>();
        expect(rulesAsStrings(sut),
            ['$SentryMaskingConstantRule<$Image>(unmask)', ...defaultRules]);
      });
      test('are ordered in the call order', () {
        var sut = SentryReplayOptions();
        sut.mask<Image>();
        sut.unmask<Image>();
        expect(rulesAsStrings(sut), [
          '$SentryMaskingConstantRule<$Image>(mask)',
          '$SentryMaskingConstantRule<$Image>(unmask)',
          ...defaultRules
        ]);
        sut = SentryReplayOptions();
        sut.unmask<Image>();
        sut.mask<Image>();
        expect(rulesAsStrings(sut), [
          '$SentryMaskingConstantRule<$Image>(unmask)',
          '$SentryMaskingConstantRule<$Image>(mask)',
          ...defaultRules
        ]);
        sut = SentryReplayOptions();
        sut.unmask<Image>();
        sut.maskCallback(
            (Element element, Image widget) => SentryMaskingDecision.mask);
        sut.mask<Image>();
        expect(rulesAsStrings(sut), [
          '$SentryMaskingConstantRule<$Image>(unmask)',
          '$SentryMaskingCustomRule<$Image>(Closure: ($Element, $Image) => $SentryMaskingDecision)',
          '$SentryMaskingConstantRule<$Image>(mask)',
          ...defaultRules
        ]);
      });
      test('maskCallback() takes precedence', () {
        final sut = SentryReplayOptions();
        sut.maskCallback(
            (Element element, Image widget) => SentryMaskingDecision.mask);
        expect(rulesAsStrings(sut), [
          '$SentryMaskingCustomRule<$Image>(Closure: ($Element, $Image) => $SentryMaskingDecision)',
          ...defaultRules
        ]);
      });
      test('User cannot add $SentryMask and $SentryUnmask rules', () {
        final sut = SentryReplayOptions();
        expect(sut.mask<SentryMask>, throwsA(isA<AssertionError>()));
        expect(sut.mask<SentryUnmask>, throwsA(isA<AssertionError>()));
        expect(sut.unmask<SentryMask>, throwsA(isA<AssertionError>()));
        expect(sut.unmask<SentryUnmask>, throwsA(isA<AssertionError>()));
        expect(
            () => sut.maskCallback<SentryMask>(
                (_, __) => SentryMaskingDecision.mask),
            throwsA(isA<AssertionError>()));
        expect(
            () => sut.maskCallback<SentryUnmask>(
                (_, __) => SentryMaskingDecision.mask),
            throwsA(isA<AssertionError>()));
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
