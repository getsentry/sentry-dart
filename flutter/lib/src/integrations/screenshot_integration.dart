import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';
import '../screenshot/screenshot_attachment_processor.dart';
import '../sentry_flutter_options.dart';
import '../sentry_widget.dart';

class ScreenshotIntegration implements Integration<SentryFlutterOptions> {

  SentryFlutterOptions? _options;

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _attachScreenshot => sentryWidgetGlobalKey.currentContext != null;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (_attachScreenshot) {
      // ignore: invalid_use_of_internal_member
      options.clientAttachmentProcessor = ScreenshotAttachmentProcessor(
              () {
            try {
              /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
              return SchedulerBinding.instance;
            } catch (_) {}
            return null;
          },
          options
      );
      _options = options;
    }
  }

  @override
  FutureOr<void> close() {
    // ignore: invalid_use_of_internal_member
    _options?.clientAttachmentProcessor = SentryClientAttachmentProcessor();
  }
}
