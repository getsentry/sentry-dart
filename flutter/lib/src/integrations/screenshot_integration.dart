import 'dart:async';

import 'package:sentry/sentry.dart';
import '../event_processor/screenshot_event_processor.dart';
import '../sentry_flutter_options.dart';

/// Adds [ScreenshotEventProcessor] to options event processors if [attachScreenshot] is true
class ScreenshotIntegration implements Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.attachScreenshot) {
      _options = options;
      options.addEventProcessor(ScreenshotEventProcessor(options));
      options.sdk.addIntegration('screenshotIntegration');
    }
  }

  @override
  FutureOr<void> close() {
    final eventProcessors = _options?.eventProcessors
            .where((element) => element.runtimeType == ScreenshotEventProcessor)
            .toList() ??
        [];

    for (var eventProcessor in eventProcessors) {
      _options?.removeEventProcessor(eventProcessor);
    }
  }
}
