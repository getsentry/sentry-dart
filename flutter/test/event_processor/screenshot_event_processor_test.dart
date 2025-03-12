@Tags(['canvasKit']) // Web renderer where this test can run
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/src/event_processor/screenshot_event_processor.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../replay/replay_test_util.dart';

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
    double? expectedMaxWidthOrHeight,
  }) async {
    // Run with real async https://stackoverflow.com/a/54021863
    await tester.runAsync(() async {
      final sut = fixture.getSut(renderer, isWeb);

      await tester.pumpWidget(SentryScreenshotWidget(
          child: Text('Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr)));

      final throwable = Exception();
      event = SentryEvent(throwable: throwable);
      hint = Hint();
      await tester.pumpAndWaitUntil(sut.apply(event, hint));

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

  testWidgets('adds screenshot attachment with masking enabled dart:io',
      (tester) async {
    fixture.options.privacy.maskAllText = true;
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

  testWidgets('does not add screenshot for feedback events', (tester) async {
    await tester.runAsync(() async {
      final sut = fixture.getSut(null, false);

      await tester.pumpWidget(
        SentryScreenshotWidget(
          child: Text('Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr),
        ),
      );

      final feedback = SentryFeedback(
        message: 'message',
        contactEmail: 'foo@bar.com',
        name: 'Joe Dirt',
        associatedEventId: null,
      );
      final feedbackEvent = SentryEvent(
        type: 'feedback',
        contexts: Contexts(feedback: feedback),
        level: SentryLevel.info,
      );

      final hint = Hint();
      await sut.apply(feedbackEvent, hint);

      expect(hint.screenshot, isNull);
    });
  });

  group('beforeCaptureScreenshot', () {
    testWidgets('does add screenshot if beforeCapture returns true',
        (tester) async {
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) {
        return true;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does add screenshot if async beforeCapture returns true',
        (tester) async {
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        return true;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does not add screenshot if beforeCapture returns false',
        (tester) async {
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) {
        return false;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: false, isWeb: false);
    });

    testWidgets('does not add screenshot if async beforeCapture returns false',
        (tester) async {
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        return false;
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: false, isWeb: false);
    });

    testWidgets('does add screenshot if beforeCapture throws', (tester) async {
      fixture.options.automatedTestMode = false;
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) {
        throw Error();
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does add screenshot if async beforeCapture throws',
        (tester) async {
      fixture.options.automatedTestMode = false;
      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) async {
        await Future<void>.delayed(Duration(milliseconds: 1));
        throw Error();
      };
      await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
          added: true, isWeb: false);
    });

    testWidgets('does add screenshot event if shouldDebounce true',
        (tester) async {
      await tester.runAsync(() async {
        var shouldDebounceValues = <bool>[];

        fixture.options.beforeCaptureScreenshot =
            (SentryEvent event, Hint hint, bool shouldDebounce) {
          shouldDebounceValues.add(shouldDebounce);
          return true;
        };

        final sut = fixture.getSut(FlutterRenderer.canvasKit, false);

        await tester.pumpWidget(
          SentryScreenshotWidget(
            child: Text(
              'Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr,
            ),
          ),
        );

        final event = SentryEvent(throwable: Exception());
        final hintOne = Hint();
        final hintTwo = Hint();

        await sut.apply(event, hintOne);
        await sut.apply(event, hintTwo);

        expect(hintOne.screenshot, isNotNull);
        expect(hintTwo.screenshot, isNotNull);

        expect(shouldDebounceValues[0], false);
        expect(shouldDebounceValues[1], true);
      });
    });

    testWidgets('passes event & hint to beforeCapture callback',
        (tester) async {
      SentryEvent? beforeScreenshotEvent;
      Hint? beforeScreenshotHint;

      fixture.options.beforeCaptureScreenshot =
          (SentryEvent event, Hint hint, bool shouldDebounce) {
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

  group("debounce", () {
    testWidgets("limits added screenshots within debounce timeframe",
        (tester) async {
      // Run with real async https://stackoverflow.com/a/54021863
      await tester.runAsync(() async {
        var firstCall = true;
        // ignore: invalid_use_of_internal_member
        fixture.options.clock = () {
          if (firstCall) {
            firstCall = false;
            return DateTime.fromMillisecondsSinceEpoch(0);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(2000 - 1);
          }
        };

        final sut = fixture.getSut(FlutterRenderer.canvasKit, false);

        await tester.pumpWidget(SentryScreenshotWidget(
            child: Text('Catching Pokémon is a snap!',
                textDirection: TextDirection.ltr)));

        final throwable = Exception();

        final firstEvent = SentryEvent(throwable: throwable);
        final firstHint = Hint();

        final secondEvent = SentryEvent(throwable: throwable);
        final secondHint = Hint();

        await sut.apply(firstEvent, firstHint);
        await sut.apply(secondEvent, secondHint);

        expect(firstHint.screenshot, isNotNull);
        expect(secondHint.screenshot, isNull);
      });
    });

    testWidgets("adds screenshots after debounce timeframe", (tester) async {
      // Run with real async https://stackoverflow.com/a/54021863
      await tester.runAsync(() async {
        var firstCall = true;
        // ignore: invalid_use_of_internal_member
        fixture.options.clock = () {
          if (firstCall) {
            firstCall = false;
            return DateTime.fromMillisecondsSinceEpoch(0);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(2001);
          }
        };

        final sut = fixture.getSut(FlutterRenderer.canvasKit, false);

        await tester.pumpWidget(
          SentryScreenshotWidget(
            child: Text(
              'Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr,
            ),
          ),
        );

        final throwable = Exception();

        final firstEvent = SentryEvent(throwable: throwable);
        final firstHint = Hint();

        final secondEvent = SentryEvent(throwable: throwable);
        final secondHint = Hint();

        await sut.apply(firstEvent, firstHint);
        await sut.apply(secondEvent, secondHint);

        expect(firstHint.screenshot, isNotNull);
        expect(secondHint.screenshot, isNotNull);
      });
    });
  });
}

class Fixture {
  late Hub hub;
  SentryFlutterOptions options = defaultTestOptions();

  Fixture() {
    options.attachScreenshot = true;
    hub = Hub(options);
  }

  ScreenshotEventProcessor getSut(
      FlutterRenderer? flutterRenderer, bool isWeb) {
    options.rendererWrapper = MockRendererWrapper(flutterRenderer);
    options.platform = MockPlatform(isWeb: isWeb);
    return ScreenshotEventProcessor(options);
  }
}
