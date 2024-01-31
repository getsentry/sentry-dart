import 'dart:io';

import 'sentry_attachment.dart';

class IoSentryAttachment extends SentryAttachment {
  /// Creates an attachment from a given path.
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  IoSentryAttachment.fromPath(
    String path, {
    String? filename,
    String? attachmentType,
    String? contentType,
  }) : this.fromFile(
          File(path),
          attachmentType: attachmentType,
          contentType: contentType,
          filename: filename,
        );

  /// Creates an attachment from a given [File].
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  IoSentryAttachment.fromFile(
    File file, {
    String? filename,
    super.attachmentType,
    super.contentType,
  }) : super.fromLoader(
          loader: () => file.readAsBytes(),
          filename: filename ?? file.uri.pathSegments.last,
        );
}
