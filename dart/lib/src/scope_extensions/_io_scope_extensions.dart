import 'dart:io';

import '../../attachment.dart';
import '../scope.dart';

extension IoScopeExtensions on Scope {
  Future<void> addAttachementPath(
    String path, {
    AttachmentType? type,
    String? mimeType,
  }) async {
    final file = File(path);

    addAttachment(
      Attachment(
        type: type,
        content: await file.readAsBytes(),
        fileName: file.uri.pathSegments.last,
        mimeType: mimeType,
      ),
    );
  }

  Future<void> addAttachementFile(
    File file, {
    AttachmentType? type,
    String? mimeType,
  }) async {
    addAttachment(
      Attachment(
        type: type,
        content: await file.readAsBytes(),
        fileName: file.uri.pathSegments.last,
        mimeType: mimeType,
      ),
    );
  }
}
