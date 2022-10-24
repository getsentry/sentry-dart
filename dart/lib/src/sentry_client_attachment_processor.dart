import 'dart:async';

import './sentry_attachment/sentry_attachment.dart';
import './protocol/sentry_event.dart';

class SentryClientAttachmentProcessor {
  Future<List<SentryAttachment>> processAttachments(List<SentryAttachment> attachments, SentryEvent event) async {
    return attachments;
  }
}
