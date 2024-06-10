@Tags(['canvasKit']) // Web renderer where this test can run
library flutter_test;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/event_processor/screenshot_event_processor.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import '../mocks.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture fixture;

  late SentryEvent event;
  late Hint hint;

  setUp(() {
    fixture = Fixture();
  });

  Future<void> _addScreenshotAttachment(
    WidgetTester tester,
    FlutterRenderer? renderer, {
    required bool isWeb,
    required bool added,
    int? expectedMaxWidthOrHeight,
  }) async {
    // Run with real async https://stackoverflow.com/a/54021863
    await tester.runAsync(() async {
      final sut = fixture.getSut(renderer, isWeb);

      await tester.pumpWidget(SentryScreenshotWidget(
          hub: fixture.hub,
          child: Text('Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr)));

      final throwable = Exception();
      event = SentryEvent(throwable: throwable);
      hint = Hint();
      await sut.apply(event, hint);

      expect(hint.screenshot != null, added);
      if (expectedMaxWidthOrHeight != null) {
        final bytes = await hint.screenshot?.bytes;
        final codec = await instantiateImageCodec(bytes!);
        final frameInfo = await codec.getNextFrame();
        final image = frameInfo.image;
        expect(
          max(image.width, image.height).toDouble(),
          moreOrLessEquals(expectedMaxWidthOrHeight.toDouble(), epsilon: 1.0),
        );
      }
    });
  }

  testWidgets('adds screenshot attachment dart:io', (tester) async {
    await _addScreenshotAttachment(tester, null, added: true, isWeb: false);
  });

  testWidgets('adds screenshot attachment with canvasKit renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
        added: true, isWeb: true);
  });

  testWidgets('does not add screenshot attachment with html renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.html,
        added: false, isWeb: true);
  });

  testWidgets('does add screenshot in correct resolution for low',
      (tester) async {
    final height = SentryScreenshotQuality.low.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.low;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: height);
  });

  testWidgets('does add screenshot in correct resolution for medium',
      (tester) async {
    final height = SentryScreenshotQuality.medium.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.medium;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: height);
  });

  testWidgets('does add screenshot in correct resolution for high',
      (tester) async {
    final widthOrHeight = SentryScreenshotQuality.high.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.high;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: widthOrHeight);
  });

  group('beforeScreenshot', () {
    testWidgets('does add screenshot if beforeScreenshot returns true',
        (tester) async {
      fixture.options.beforeScreenshot = (SentryEvent event, {Hint? hint}) {
        return true;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does add screenshot if async beforeScreenshot returns true',
        (tester) async {
      fixture.options.beforeScreenshot =
          (SentryEvent event, {Hint? hint}) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        return true;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does not add screenshot if beforeScreenshot returns false',
        (tester) async {
      fixture.options.beforeScreenshot = (SentryEvent event, {Hint? hint}) {
        return false;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: false, isWeb: false);
    });

    testWidgets(
        'does not add screenshot if async beforeScreenshot returns false',
        (tester) async {
      fixture.options.beforeScreenshot =
          (SentryEvent event, {Hint? hint}) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        return false;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: false, isWeb: false);
    });

    testWidgets('does add screenshot if beforeScreenshot throws',
        (tester) async {
      fixture.options.beforeScreenshot = (SentryEvent event, {Hint? hint}) {
        throw Error();
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does add screenshot if async beforeScreenshot throws',
        (tester) async {
      fixture.options.beforeScreenshot =
          (SentryEvent event, {Hint? hint}) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        throw Error();
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('passes event & hint to beforeScreenshot callback',
        (tester) async {
      SentryEvent? beforeScreenshotEvent;
      Hint? beforeScreenshotHint;

      fixture.options.beforeScreenshot = (SentryEvent event, {Hint? hint}) {
        beforeScreenshotEvent = event;
        beforeScreenshotHint = hint;
        return true;
      };

      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);

      expect(beforeScreenshotEvent, event);
      expect(beforeScreenshotHint, hint);
    });
  });
}

class Fixture {
  late Hub hub;
  SentryFlutterOptions options = SentryFlutterOptions(dsn: fakeDsn);

  Fixture() {
    options.attachScreenshot = true;
    hub = Hub(options);
  }

  ScreenshotEventProcessor getSut(
      FlutterRenderer? flutterRenderer, bool isWeb) {
    options.rendererWrapper = MockRendererWrapper(flutterRenderer);
    options.platformChecker = MockPlatformChecker(isWebValue: isWeb);
    return ScreenshotEventProcessor(options);
  }
}
