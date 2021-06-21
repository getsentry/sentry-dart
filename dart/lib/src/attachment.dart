import 'dart:typed_data';
export 'attachment_extensions/attachment_extensions.dart';

// https://develop.sentry.dev/sdk/envelopes/#attachment

/// Arbitrary content which gets attached to an event.
class Attachment {
  Attachment({
    required this.content,
    required this.fileName,
    AttachmentType? type,
    String? mimeType,
  })  : mimeType = mimeType ?? 'application/octet-stream',
        type = type ?? AttachmentType.attachment;

  /// Creates an [Attachment] from a [Uint8List]
  factory Attachment.fromUint8List(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    return Attachment(
      type: type,
      content: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// Creates an [Attachment] from a [List<int>]
  factory Attachment.fromIntList(
    List<int> bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    return Attachment(
      type: type,
      content: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// Creates an [Attachment] from [ByteData]
  factory Attachment.fromByteData(
    ByteData bytes,
    String fileName, {
    String? mimeType,
    AttachmentType? type,
  }) {
    return Attachment(
      type: type,
      content: bytes.buffer.asUint8List(),
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// Attachment type.
  final AttachmentType type;

  /// Attachment content.
  final Uint8List content;

  /// Attachment file name.
  final String fileName;

  /// Attachment content type.
  final String mimeType;
}

/// Attachment type.
enum AttachmentType {
  /// Standard attachment without special meaning.
  attachment,

  /// Minidump file that creates an error event and is symbolicated.
  /// The file should start with the <code>MDMP</code> magic bytes.
  minidump,

  /// Apple crash report file that creates an error event and is symbolicated.
  appleCrashReport,

  /// XML file containing UE4 crash meta data.
  /// During event ingestion, event contexts and extra fields are extracted from
  /// this file.
  unrealContext,

  /// Plain-text log file obtained from UE4 crashes.
  /// During event ingestion, the last logs are extracted into event
  /// breadcrumbs.
  unrealLogs
}

extension AttachmentTypeX on AttachmentType {
  String toSentryIdentifier() {
    switch (this) {
      case AttachmentType.attachment:
        return 'event.attachment';
      case AttachmentType.minidump:
        return 'event.minidump';
      case AttachmentType.appleCrashReport:
        return 'event.applecrashreport';
      case AttachmentType.unrealContext:
        return 'unreal.context';
      case AttachmentType.unrealLogs:
        return 'unreal.logs';
    }
  }
}
