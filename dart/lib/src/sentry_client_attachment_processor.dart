import 'dart:async';

import 'package:meta/meta.dart';

import './sentry_attachment/sentry_attachment.dart';
import './protocol/sentry_event.dart';

@internal
class SentryClientAttachmentProcessor {
  Future<List<SentryAttachment>> processAttachments(
      List<SentryAttachment> attachments, SentryEvent event) async {
    return attachments;
  }
}
