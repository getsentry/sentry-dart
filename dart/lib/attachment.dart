import 'dart:typed_data';

// https://develop.sentry.dev/sdk/envelopes/#attachment
class Attachment {
  Attachment({
    required this.content,
    required this.fileName,
    AttachmentType? type,
    String? mimeType,
  })  : mimeType = mimeType ?? 'application/octet-stream',
        type = type ?? AttachmentType.attachment;

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
