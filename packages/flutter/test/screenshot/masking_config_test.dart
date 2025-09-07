import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screenshot/masking_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final alwaysEnabledRules = [
    'SentryMaskingConstantRule<SentryMask>(mask)',
    'SentryMaskingConstantRule<SentryUnmask>(unmask)',
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
    group('SentryMaskingConstantRule($value)', () {
      final rule = SentryMaskingConstantRule<Image>(
        mask: value == SentryMaskingDecision.mask,
        name: 'Image',
      );
      final sut = SentryMaskingConfig([rule]);
      testWidgets('will mask widget by type', (tester) async {
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Image>();
        expect(sut.shouldMask(element, element.widget), value);
      });

      testWidgets('will mask subtype widget by type', (tester) async {
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<CustomImageWidget>();
        expect(sut.shouldMask(element, element.widget), value);
      });

      testWidgets('will not mask widget of a different type', (tester) async {
        final rootElement = await pumpTestElement(tester);
        final element = rootElement.findFirstOfType<Text>();
        expect(sut.shouldMask(element, element.widget),
            SentryMaskingDecision.continueProcessing);
      }, skip: value == SentryMaskingDecision.unmask);
    });
  }

  group('SentryMaskingCustomRule', () {
    testWidgets('only called for specified type', (tester) async {
      final called = <Type, int>{};
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
          callback: (e, w) {
            called[w.runtimeType] = (called[w.runtimeType] ?? 0) + 1;
            return SentryMaskingDecision.continueProcessing;
          },
          name: 'Image',
          description: 'custom callback',
        ),
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
          callback: (e, w) => SentryMaskingDecision.continueProcessing,
          name: 'Image',
          description: 'custom callback',
        ),
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => SentryMaskingDecision.mask,
          name: 'Image',
          description: 'custom callback',
        ),
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => fail('should not be called'),
          name: 'Image',
          description: 'custom callback',
        ),
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(
          sut.shouldMask(element, element.widget), SentryMaskingDecision.mask);
    });

    testWidgets('stops iteration on first "unmask" rule', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => SentryMaskingDecision.continueProcessing,
          name: 'Image',
          description: 'custom callback',
        ),
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => SentryMaskingDecision.unmask,
          name: 'Image',
          description: 'custom callback',
        ),
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => fail('should not be called'),
          name: 'Image',
          description: 'custom callback',
        )
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget),
          SentryMaskingDecision.unmask);
    });

    testWidgets('returns false if no rule matches', (tester) async {
      final sut = SentryMaskingConfig([
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => SentryMaskingDecision.continueProcessing,
          name: 'Image',
          description: 'custom callback',
        ),
        SentryMaskingCustomRule<Image>(
          callback: (e, w) => SentryMaskingDecision.continueProcessing,
          name: 'Image',
          description: 'custom callback',
        ),
      ]);
      final rootElement = await pumpTestElement(tester);
      final element = rootElement.findFirstOfType<Image>();
      expect(sut.shouldMask(element, element.widget),
          SentryMaskingDecision.continueProcessing);
    });
  });

  group('$SentryReplayOptions.buildMaskingConfig()', () {
    List<String> rulesAsStrings(SentryPrivacyOptions options) {
      final config =
          options.buildMaskingConfig(MockLogger().call, RuntimeChecker());
      return config.rules
          .map((rule) => rule.toString())
          // These normalize the string on VM & js & wasm:
          .map((str) => str.replaceAll(
              RegExp(r"=> SentryMaskingDecision from:? .*", dotAll: true),
              '=> SentryMaskingDecision)'))
          .map((str) => str.replaceAll(
              ' from: (element, widget) => masking_config.SentryMaskingDecision.mask',
              ''))
          .toList();
    }

    test('defaults', () {
      final sut = SentryPrivacyOptions();
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        'SentryMaskingCustomRule<Image>(Mask all images except asset images.)',
        'SentryMaskingConstantRule<Text>(mask)',
        'SentryMaskingConstantRule<EditableText>(mask)',
        'SentryMaskingConstantRule<RichText>(mask)',
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ]);
    });

    test('maskAllImages=true & maskAssetImages=true', () {
      final sut = SentryPrivacyOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = true;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        'SentryMaskingConstantRule<Image>(mask)',
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ]);
    });

    test('maskAllImages=true & maskAssetImages=false', () {
      final sut = SentryPrivacyOptions()
        ..maskAllText = false
        ..maskAllImages = true
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        'SentryMaskingCustomRule<Image>(Mask all images except asset images.)',
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ]);
    });

    test('maskAllText=true', () {
      final sut = SentryPrivacyOptions()
        ..maskAllText = true
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        'SentryMaskingConstantRule<Text>(mask)',
        'SentryMaskingConstantRule<EditableText>(mask)',
        'SentryMaskingConstantRule<RichText>(mask)',
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ]);
    });

    test('maskAllText=false', () {
      final sut = SentryPrivacyOptions()
        ..maskAllText = false
        ..maskAllImages = false
        ..maskAssetImages = false;
      expect(rulesAsStrings(sut), [
        ...alwaysEnabledRules,
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ]);
    });

    test(
        'SensitiveContent rule is automatically added when current Flutter version is equal or newer than 3.33',
        () {
      final sut = SentryPrivacyOptions();
      final version = FlutterVersion.version!;
      final dot = version.indexOf('.');
      final major = int.tryParse(version.substring(0, dot));
      final nextDot = version.indexOf('.', dot + 1);
      final minor = int.tryParse(
          version.substring(dot + 1, nextDot == -1 ? version.length : nextDot));

      if (major! > 3 || (major == 3 && minor! >= 33)) {
        expect(
            rulesAsStrings(sut).contains(
                'SentryMaskingCustomRule<SensitiveContent>(Mask SensitiveContent widget.)'),
            isTrue,
            reason: 'Test failed with version: ${FlutterVersion.version}');
      } else {
        expect(
            rulesAsStrings(sut).contains(
                'SentryMaskingCustomRule<SensitiveContent>(Mask SensitiveContent widget.)'),
            isFalse,
            reason: 'Test failed with version: ${FlutterVersion.version}');
      }
    }, skip: FlutterVersion.version == null);

    group('user rules', () {
      final defaultRules = [
        ...alwaysEnabledRules,
        'SentryMaskingCustomRule<Image>(Mask all images except asset images.)',
        'SentryMaskingConstantRule<Text>(mask)',
        'SentryMaskingConstantRule<EditableText>(mask)',
        'SentryMaskingConstantRule<RichText>(mask)',
        ..._maybeWithSensitiveContent(),
        'SentryMaskingCustomRule<Widget>(Debug-mode-only warning for potentially sensitive widgets.)'
      ];

      test('mask() takes precedence', () {
        final sut = SentryPrivacyOptions();
        sut.mask<Image>();
        expect(rulesAsStrings(sut), [
          'SentryMaskingConstantRule<Image>(mask)',
          ...defaultRules,
        ]);
      });

      test('unmask() takes precedence', () {
        final sut = SentryPrivacyOptions();
        sut.unmask<Image>();
        expect(rulesAsStrings(sut), [
          'SentryMaskingConstantRule<Image>(unmask)',
          ...defaultRules,
        ]);
      });

      test('are ordered in the call order', () {
        var sut = SentryPrivacyOptions();
        sut.mask<Image>();
        sut.unmask<Image>();
        expect(rulesAsStrings(sut), [
          'SentryMaskingConstantRule<Image>(mask)',
          'SentryMaskingConstantRule<Image>(unmask)',
          ...defaultRules
        ]);
        sut = SentryPrivacyOptions();
        sut.unmask<Image>();
        sut.mask<Image>();
        expect(rulesAsStrings(sut), [
          'SentryMaskingConstantRule<Image>(unmask)',
          'SentryMaskingConstantRule<Image>(mask)',
          ...defaultRules
        ]);
        sut = SentryPrivacyOptions();
        sut.unmask<Image>();
        sut.maskCallback(
            (Element element, Image widget) => SentryMaskingDecision.mask);
        sut.mask<Image>();
        expect(rulesAsStrings(sut), [
          'SentryMaskingConstantRule<Image>(unmask)',
          'SentryMaskingCustomRule<Image>(Custom callback-based rule (description unspecified))',
          'SentryMaskingConstantRule<Image>(mask)',
          ...defaultRules
        ]);
      });

      test('maskCallback() takes precedence', () {
        final sut = SentryPrivacyOptions();
        sut.maskCallback(
            (Element element, Image widget) => SentryMaskingDecision.mask);
        expect(rulesAsStrings(sut), [
          'SentryMaskingCustomRule<Image>(Custom callback-based rule (description unspecified))',
          ...defaultRules,
        ]);
      });
      test('User cannot add $SentryMask and $SentryUnmask rules', () {
        final sut = SentryPrivacyOptions();
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

  testWidgets('ignores InheritedWidget and does not log', (tester) async {
    final logger = MockLogger();
    final options = SentryPrivacyOptions();
    final config =
        options.buildMaskingConfig(logger.call, MockRuntimeChecker());

    final rootElement = await pumpTestElement(tester, children: const [
      _PasswordInherited(child: Text('child')),
    ]);

    final element = rootElement.findFirstOfType<_PasswordInherited>();
    expect(config.shouldMask(element, element.widget),
        SentryMaskingDecision.continueProcessing);

    // The debug rule contains a RegExp that matches 'password'. Our widget
    // name contains it but because it's an InheritedWidget it should be
    // ignored and thus no warning is logged.
    expect(logger.items.where((i) => i.level == SentryLevel.warning), isEmpty);
  });
}

List<String> _maybeWithSensitiveContent() {
  final version = FlutterVersion.version;
  if (version == null) {
    return [];
  }
  final dot = version.indexOf('.');
  final major = int.tryParse(version.substring(0, dot));
  final nextDot = version.indexOf('.', dot + 1);
  final minor = int.tryParse(
      version.substring(dot + 1, nextDot == -1 ? version.length : nextDot));
  if (major! > 3 || (major == 3 && minor! >= 33)) {
    return [
      'SentryMaskingCustomRule<SensitiveContent>(Mask SensitiveContent widget.)'
    ];
  } else {
    return [];
  }
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

class _PasswordInherited extends InheritedWidget {
  const _PasswordInherited({required super.child});

  @override
  bool updateShouldNotify(covariant _PasswordInherited oldWidget) => false;
}
