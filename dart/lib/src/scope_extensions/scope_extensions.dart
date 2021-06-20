export '_io_scope_extensions.dart'
    if (dart.library.html) '_web_scope_extensions.dart';

import 'dart:typed_data';

import '../../attachment.dart';
import '../scope.dart';

extension ScopeExtensions on Scope {
  void addAttachmentBytes(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    addAttachment(Attachment(
      type: type,
      content: bytes,
      fileName: fileName,
      mimeType: mimeType,
    ));
  }

  void addAttachmentIntList(
    List<int> bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    addAttachment(Attachment(
      type: type,
      content: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType: mimeType,
    ));
  }

  void addAttachmentByteData(
    ByteData bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    addAttachment(Attachment(
      type: type,
      content: bytes.buffer.asUint8List(),
      fileName: fileName,
      mimeType: mimeType,
    ));
  }
}
