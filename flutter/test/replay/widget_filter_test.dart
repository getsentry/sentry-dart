import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/widget_filter.dart';

import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const defaultBounds = Rect.fromLTRB(0, 0, 1000, 1000);
  final rootBundle = TestAssetBundle();
  final otherBundle = TestAssetBundle();

  final createSut =
      ({bool redactImages = false, bool redactText = false}) => WidgetFilter(
            logger: (level, message, {exception, logger, stackTrace}) {},
            redactImages: redactImages,
            redactText: redactText,
            rootAssetBundle: rootBundle,
          );

  boundsRect(WidgetFilterItem item) =>
      '${item.bounds.width.floor()}x${item.bounds.height.floor()}';

  group('redact text', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(element, 1.0, defaultBounds);
      expect(sut.items.length, 4);
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
      expect(sut.items.length, 4);
      expect(boundsRect(sut.items[0]), '624x48');
      expect(boundsRect(sut.items[1]), '169x20');
      expect(boundsRect(sut.items[2]), '800x192');
      expect(boundsRect(sut.items[3]), '50x20');
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
        final sut = createSut(redactImages: true);

        expect(sut.isBuiltInAssetImage(newAssetImage('')), isTrue);
        expect(sut.isBuiltInAssetImage(newAssetImage('', bundle: rootBundle)),
            isTrue);
        expect(sut.isBuiltInAssetImage(newAssetImage('', bundle: otherBundle)),
            isFalse);
        expect(
            sut.isBuiltInAssetImage(newAssetImage('',
                bundle: SentryAssetBundle(bundle: rootBundle))),
            isTrue);
        expect(
            sut.isBuiltInAssetImage(newAssetImage('',
                bundle: SentryAssetBundle(bundle: otherBundle))),
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
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}
