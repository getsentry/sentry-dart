import 'package:sentry/sentry.dart';
import '../event_processor/screenshot_event_processor.dart';
import '../sentry_flutter_options.dart';

/// Adds [ScreenshotEventProcessor] to options event processors if
/// [SentryFlutterOptions.attachScreenshot] is true
class ScreenshotIntegration implements Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;
  ScreenshotEventProcessor? _screenshotEventProcessor;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (options.attachScreenshot) {
      _options = options;
      final screenshotEventProcessor = ScreenshotEventProcessor(options);
      options.addEventProcessor(screenshotEventProcessor);
      _screenshotEventProcessor = screenshotEventProcessor;
      options.sdk.addIntegration('screenshotIntegration');
    }
  }

  @override
  void close() {
    final screenshotEventProcessor = _screenshotEventProcessor;
    if (screenshotEventProcessor != null) {
      _options?.removeEventProcessor(screenshotEventProcessor);
      _screenshotEventProcessor = null;
    }
  }
}
