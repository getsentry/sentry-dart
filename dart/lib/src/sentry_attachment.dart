import 'dart:async';
import 'dart:typed_data';
export 'sentry_attachment_extensions/attachment_extensions.dart';

// https://develop.sentry.dev/sdk/envelopes/#attachment

typedef ContentLoader = FutureOr<Uint8List> Function();

/// Arbitrary content which gets attached to an event.
class SentryAttachment {
  SentryAttachment({
    required ContentLoader loader,
    required this.filename,
    String? attachmentType,
    this.contentType,
  })  : _loader = loader,
        attachmentType = attachmentType ?? AttachmentType.attachment;

  /// Creates an [SentryAttachment] from a [Uint8List]
  factory SentryAttachment.fromUint8List(
    Uint8List bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
  }) {
    return SentryAttachment(
      attachmentType: attachmentType,
      loader: () => bytes,
      filename: fileName,
      contentType: contentType,
    );
  }

  /// Creates an [SentryAttachment] from a [List<int>]
  factory SentryAttachment.fromIntList(
    List<int> bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
  }) {
    return SentryAttachment(
      attachmentType: attachmentType,
      loader: () => Uint8List.fromList(bytes),
      filename: fileName,
      contentType: contentType,
    );
  }

  /// Creates an [SentryAttachment] from [ByteData]
  factory SentryAttachment.fromByteData(
    ByteData bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
  }) {
    return SentryAttachment(
      attachmentType: attachmentType,
      loader: () => bytes.buffer.asUint8List(),
      filename: fileName,
      contentType: contentType,
    );
  }

  /// Attachment type.
  /// Should be one of types given in [AttachmentType].
  final String attachmentType;

  /// Attachment content.
  FutureOr<Uint8List> get bytes => _loader();

  final ContentLoader _loader;

  /// Attachment file name.
  final String filename;

  /// Attachment content type.
  /// Inferred by Sentry if it's not given.
  final String? contentType;
}

/// Attachment type.
class AttachmentType {
  /// Standard attachment without special meaning.
  static const String attachment = 'event.attachment';

  /// Minidump file that creates an error event and is symbolicated.
  /// The file should start with the `MDMP` magic bytes.
  static const String minidump = 'event.minidump';

  /// Apple crash report file that creates an error event and is symbolicated.
  static const String appleCrashReport = 'event.applecrashreport';

  /// XML file containing UE4 crash meta data.
  /// During event ingestion, event contexts and extra fields are extracted from
  /// this file.
  static const String unrealContext = 'unreal.context';

  /// Plain-text log file obtained from UE4 crashes.
  /// During event ingestion, the last logs are extracted into event
  /// breadcrumbs.
  static const String unrealLogs = 'unreal.logs';
}
