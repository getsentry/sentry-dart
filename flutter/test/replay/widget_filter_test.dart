import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/widget_filter.dart';

import 'test_widget.dart';

// Note: these tests predate existance of `SentryMaskingConfig` which now
// takes care of the decision making whether something is masked or not.
// We'll keep these tests although they're not unit-tests anymore.
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const defaultBounds = Rect.fromLTRB(0, 0, 1000, 1000);
  final rootBundle = TestAssetBundle();
  final otherBundle = TestAssetBundle();

  final createSut = ({bool redactImages = false, bool redactText = false}) {
    final replayOptions = SentryReplayOptions();
    replayOptions.redactAllImages = redactImages;
    replayOptions.redactAllText = redactText;
    return WidgetFilter(replayOptions.buildMaskingConfig(),
        (level, message, {exception, logger, stackTrace}) {});
  };

  boundsRect(WidgetFilterItem item) =>
      '${item.bounds.width.floor()}x${item.bounds.height.floor()}';

  group('redact text', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 5);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactText: false);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 100, 100));
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 5);
      expect(boundsRect(sut.items[0]), '624x48');
      expect(boundsRect(sut.items[1]), '169x20');
      expect(boundsRect(sut.items[2]), '800x192');
      expect(boundsRect(sut.items[3]), '800x24');
      expect(boundsRect(sut.items[4]), '50x20');
    });
  });

  group('redact images', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
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
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen',
        (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, Rect.fromLTRB(0, 0, 500, 100));
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
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
    sut.obscure(element, 1.0, defaultBounds);
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
    sut.obscure(element, 1.0, defaultBounds);
    expect(sut.items, isEmpty);
  });
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}
