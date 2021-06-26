import 'dart:io';

import '../sentry_attachment.dart';
import '../scope.dart';

extension IoAttachmentExtensions on Scope {
  /// Creates an attachment from a given path.
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  static SentryAttachment fromPath(
    String path, {
    String? filename,
    String? attachmentType,
    String? contentType,
  }) {
    final file = File(path);

    return fromFile(
      file,
      attachmentType: attachmentType,
      contentType: contentType,
      filename: filename,
    );
  }

  /// Creates an attachment from a given [File].
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  static SentryAttachment fromFile(
    File file, {
    String? filename,
    String? attachmentType,
    String? contentType,
  }) {
    return SentryAttachment(
      attachmentType: attachmentType,
      loader: () => file.readAsBytes(),
      filename: filename ?? file.uri.pathSegments.last,
      contentType: contentType,
    );
  }
}
