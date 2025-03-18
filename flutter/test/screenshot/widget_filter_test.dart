import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screenshot/widget_filter.dart';

import '../mocks.dart';
import 'test_widget.dart';

// Note: these tests predate existance of `SentryMaskingConfig` which now
// takes care of the decision making whether something is masked or not.
// We'll keep these tests although they're not unit-tests anymore.
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rootBundle = TestAssetBundle();
  final otherBundle = TestAssetBundle();
  final logger = MockLogger();
  final colorScheme = WidgetFilterColorScheme(
      defaultMask: Colors.white,
      defaultTextMask: Colors.green,
      background: Colors.red);

  final createSut = (
      {bool redactImages = false,
      bool redactText = false,
      RuntimeChecker? runtimeChecker}) {
    final privacyOptions = SentryPrivacyOptions()
      ..maskAllImages = redactImages
      ..maskAllText = redactText;
    logger.clear();
    final maskingConfig = privacyOptions.buildMaskingConfig(
        logger.call, runtimeChecker ?? RuntimeChecker());
    return WidgetFilter(maskingConfig, logger.call);
  };

  boundsRect(WidgetFilterItem item) =>
      '${item.bounds.width.floor()}x${item.bounds.height.floor()}';

  group('redact text', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 6);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactText: false);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          bounds: Rect.fromLTRB(0, 0, 100, 100),
          colorScheme: colorScheme);
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 6);
      expect(
          sut.items.map(boundsRect),
          unorderedEquals([
            '624x48',
            '169x20',
            '800x192',
            '800x24',
            '800x24',
            '50x20',
          ]));
    });
  });

  group('redact images', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 3);
    });

    // Note: we cannot currently test actual asset images without either:
    // - introducing assets to the package because those wouldn't get tree-shaken in final user apps (https://github.com/flutter/flutter/issues/64106)
    // - using a mock asset bundle implementation, because the image widget loads AssetManifest.bin first and we don't have a way to mock that (https://github.com/flutter/flutter/issues/126860)
    // Therefore we only check the function that actually decides whether the image is a built-in asset image.
    for (var newAssetImage in [AssetImage.new, ExactAssetImage.new]) {
      testWidgets(
          'recognizes ${newAssetImage('').runtimeType} from the root bundle',
          (tester) async {
        expect(WidgetFilter.isBuiltInAssetImage(newAssetImage(''), rootBundle),
            isTrue);
        expect(
            WidgetFilter.isBuiltInAssetImage(
                newAssetImage('', bundle: rootBundle), rootBundle),
            isTrue);
        expect(
            WidgetFilter.isBuiltInAssetImage(
                newAssetImage('', bundle: otherBundle), rootBundle),
            isFalse);
        expect(
            WidgetFilter.isBuiltInAssetImage(
                newAssetImage('',
                    bundle: SentryAssetBundle(bundle: rootBundle)),
                rootBundle),
            isTrue);
        expect(
            WidgetFilter.isBuiltInAssetImage(
                newAssetImage('',
                    bundle: SentryAssetBundle(bundle: otherBundle)),
                rootBundle),
            isFalse);
      });
    }

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactImages: false);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          bounds: Rect.fromLTRB(0, 0, 500, 100),
          colorScheme: colorScheme);
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme);
      expect(sut.items.length, 3);
      expect(boundsRect(sut.items[0]), '1x1');
      expect(boundsRect(sut.items[1]), '1x1');
      expect(boundsRect(sut.items[2]), '50x20');
    });
  });

  testWidgets('respects $SentryMask', (tester) async {
    final sut = createSut(redactText: false, redactImages: false);
    final element = await pumpTestElement(tester, children: [
      SentryMask(Padding(padding: EdgeInsets.all(100), child: Text('foo'))),
    ]);
    sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme);
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '344x248');
  });

  testWidgets('respects $SentryUnmask', (tester) async {
    final sut = createSut(redactText: true, redactImages: true);
    final element = await pumpTestElement(tester, children: [
      SentryUnmask(Text('foo')),
      SentryUnmask(newImage()),
      SentryUnmask(SentryMask(Text('foo'))),
    ]);
    sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme);
    expect(sut.items, isEmpty);
  });

  testWidgets('obscureElementOrParent', (tester) async {
    final sut = createSut(redactText: true);
    final element = await pumpTestElement(tester, children: [
      Padding(padding: EdgeInsets.all(100), child: Text('foo')),
    ]);
    sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme);
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '144x48');
    sut.throwInObscure = true;
    sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme);
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '344x248');
  });

  group('warning on sensitive widgets', () {
    assert(MockRuntimeCheckerBuildMode.values.length == 3);
    for (final buildMode in MockRuntimeCheckerBuildMode.values) {
      testWidgets(buildMode.name, (tester) async {
        final sut = createSut(
            redactText: true,
            runtimeChecker: MockRuntimeChecker(buildMode: buildMode));
        final element =
            await pumpTestElement(tester, children: [CustomPasswordWidget()]);
        sut.obscure(
            context: element,
            root: element.renderObject as RenderRepaintBoundary,
            colorScheme: colorScheme);
        final logMessages = logger.items
            .where((item) => item.level == SentryLevel.warning)
            .map((item) => item.message)
            .toList();

        if (buildMode == MockRuntimeCheckerBuildMode.debug) {
          expect(
              logMessages,
              anyElement(contains(
                  'name matches widgets that should usually be masked because they may contain sensitive data')));
        } else {
          expect(logMessages, isEmpty);
        }
      });
    }
  });
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}

class CustomPasswordWidget extends Column {
  const CustomPasswordWidget({super.key});
}
