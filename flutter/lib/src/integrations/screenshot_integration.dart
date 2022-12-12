import 'dart:async';

import 'package:sentry/sentry.dart';
import '../event_processor/screenshot_event_processor.dart';
import '../sentry_flutter_options.dart';

/// Adds [ScreenshotEventProcessor] to options event processors if [attachScreenshot] is true
class ScreenshotIntegration implements Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;
  ScreenshotEventProcessor? screenshotEventProcessor;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.attachScreenshot) {
      _options = options;
      final screenshotEventProcessor = ScreenshotEventProcessor(options);
      options.addEventProcessor(screenshotEventProcessor);
      this.screenshotEventProcessor = screenshotEventProcessor;
      options.sdk.addIntegration('screenshotIntegration');
    }
  }

  @override
  FutureOr<void> close() {
    final screenshotEventProcessor = this.screenshotEventProcessor;
    if (screenshotEventProcessor != null) {
      _options?.removeEventProcessor(screenshotEventProcessor);
      this.screenshotEventProcessor = null;
    }
  }
}
