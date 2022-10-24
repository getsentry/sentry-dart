import 'dart:async';

import 'package:sentry/sentry.dart';
import '../integrations/native_app_start_integration.dart';
import '../sentry_widget.dart';
import 'screenshot_attachment.dart';

class ScreenshotAttachmentProcessor implements SentryClientAttachmentProcessor {
  final SchedulerBindingProvider _schedulerBindingProvider;
  final SentryOptions _options;

  ScreenshotAttachmentProcessor(this._schedulerBindingProvider, this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _attachScreenshot => sentryWidgetGlobalKey.currentContext != null;

  @override
  Future<List<SentryAttachment>> processAttachments(
      List<SentryAttachment> attachments, SentryEvent event) async {
    if (event.exceptions == null && event.throwable == null && _attachScreenshot) {
      return attachments;
    }
    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null) {
      final attachmentsWithScreenshot = <SentryAttachment>[];
      attachmentsWithScreenshot.addAll(attachments);
      attachmentsWithScreenshot
          .add(ScreenshotAttachment(schedulerBinding, _options));
      return attachmentsWithScreenshot;
    } else {
      return attachments;
    }
  }
}
