import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/sentry_private.dart';
import '../screenshot/screenshot_attachment_processor.dart';
import '../sentry_flutter_options.dart';

/// Adds [ScreenshotAttachmentProcessor] to options if [attachScreenshot] is true
class ScreenshotIntegration implements Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.attachScreenshot) {
      // ignore: invalid_use_of_internal_member
      options.clientAttachmentProcessor =
          ScreenshotAttachmentProcessor(options);
      _options = options;
    }
    options.sdk.addIntegration('screenshotIntegration');
  }

  @override
  FutureOr<void> close() {
    // ignore: invalid_use_of_internal_member
    _options?.clientAttachmentProcessor = SentryClientAttachmentProcessor();
  }
}
