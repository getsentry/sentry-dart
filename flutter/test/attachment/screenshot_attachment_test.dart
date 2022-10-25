import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/screenshot/screenshot_attachment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$ScreenshotAttachment ctor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('properties', () async {
      final sut = fixture.getSut();

      expect(sut.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(sut.contentType, 'image/png');
      expect(sut.filename, 'screenshot.png');
      expect(sut.addToTransactions, true);
    });
  });
}

class Fixture {
  final schedulerBinding = SchedulerBinding.instance;
  final options = SentryOptions();

  ScreenshotAttachment getSut() {
    return ScreenshotAttachment(SchedulerBinding.instance, SentryOptions());
  }
}
