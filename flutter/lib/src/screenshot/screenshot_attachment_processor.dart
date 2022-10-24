import 'dart:async';

import 'package:sentry/sentry.dart';
import '../integrations/native_app_start_integration.dart';
import 'screenshot_attachment.dart';

class ScreenshotAttachmentProcessor implements SentryClientAttachmentProcessor {
  final SchedulerBindingProvider _schedulerBindingProvider;
  final SentryOptions _options;

  ScreenshotAttachmentProcessor(this._schedulerBindingProvider, this._options);

  @override
  Future<List<SentryAttachment>> processAttachments(
      List<SentryAttachment> attachments, SentryEvent event) async {
    if (event.exceptions == null && event.throwable == null) {
      return attachments;
    }
    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null) {
      final attachmentsWithScreenshot = attachments;
      attachmentsWithScreenshot
          .add(ScreenshotAttachment(schedulerBinding, _options));
      return attachmentsWithScreenshot;
    } else {
      return attachments;
    }
  }
}
