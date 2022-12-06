@Tags(['canvasKit']) // Web renderer where this test can run

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/event_processor/screenshot_event_processor.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import '../mocks.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> _addScreenshotAttachment(
      WidgetTester tester, FlutterRenderer renderer, bool added) async {
    // Run with real async https://stackoverflow.com/a/54021863
    await tester.runAsync(() async {
      final sut = fixture.getSut(renderer);

      await tester.pumpWidget(SentryScreenshotWidget(
          child: Text('Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr)));

      final throwable = Exception();
      final event = SentryEvent(throwable: throwable);
      final hint = Hint();
      await sut.apply(event, hint: hint);

      expect(hint.screenshot != null, added);
    });
  }

  testWidgets('adds screenshot attachment with skia renderer', (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.skia, true);
  });

  testWidgets('adds screenshot attachment with canvasKit renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit, true);
  });

  testWidgets('does not add screenshot attachment with html renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.html, false);
  });

  testWidgets('does not add screenshot attachment with unknown renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.unknown, false);
  });
}

class Fixture {
  SentryFlutterOptions options = SentryFlutterOptions(dsn: fakeDsn);

  ScreenshotEventProcessor getSut(FlutterRenderer flutterRenderer) {
    options.rendererWrapper = MockRendererWrapper(flutterRenderer);
    return ScreenshotEventProcessor(options);
  }
}
