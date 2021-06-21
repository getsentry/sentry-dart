import 'dart:io';

import '../attachment.dart';
import '../scope.dart';

extension IoScopeExtensions on Scope {
  /// Creates an attachment from a given path.
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  static Future<Attachment> fromPath(
    String path, {
    AttachmentType? type,
    String? mimeType,
  }) async {
    final file = File(path);

    return Attachment(
      type: type,
      content: await file.readAsBytes(),
      fileName: file.uri.pathSegments.last,
      mimeType: mimeType,
    );
  }

  /// Creates an attachment from a given [File].
  /// Only available on `dart:io` platforms.
  /// Not available on web.
  static Future<Attachment> fromFile(
    File file, {
    AttachmentType? type,
    String? mimeType,
  }) async {
    return Attachment(
      type: type,
      content: await file.readAsBytes(),
      fileName: file.uri.pathSegments.last,
      mimeType: mimeType,
    );
  }
}
