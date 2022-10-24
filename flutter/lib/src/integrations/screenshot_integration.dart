import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';
import '../screenshot/screenshot_attachment_processor.dart';
import '../sentry_flutter_options.dart';

class ScreenshotIntegration implements Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    // ignore: invalid_use_of_internal_member
    options.clientAttachmentProcessor = ScreenshotAttachmentProcessor(() {
      try {
        /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
        return SchedulerBinding.instance;
      } catch (_) {}
      return null;
    }, options);
    _options = options;
  }

  @override
  FutureOr<void> close() {
    // ignore: invalid_use_of_internal_member
    _options?.clientAttachmentProcessor = SentryClientAttachmentProcessor();
  }
}
