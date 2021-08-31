import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('ScreenshotAttachment default values', () {
    final attachment = ScreenshotAttachment();
    expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
    expect(attachment.contentType, 'image/png');
    expect(attachment.filename, 'screenshot.png');
  });

  testWidgets('creates screenshot', (tester) async {
    await tester.runAsync(() async {
      final widget = SentryScreenshot(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Hello World'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);

      final screenshot = await ScreenshotAttachment().createScreenshot();

      expect(screenshot, isNotNull);
    });
  });
}
