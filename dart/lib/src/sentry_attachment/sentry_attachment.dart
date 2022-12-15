import 'dart:async';
import 'dart:typed_data';

import '../protocol/sentry_view_hierarchy.dart';
import '../utils.dart';

// https://develop.sentry.dev/sdk/features/#attachments
// https://develop.sentry.dev/sdk/envelopes/#attachment

typedef ContentLoader = FutureOr<Uint8List> Function();

/// Arbitrary content which gets attached to an event.
class SentryAttachment {
  /// Standard attachment without special meaning.
  static const String typeAttachmentDefault = 'event.attachment';

  /// Minidump file that creates an error event and is symbolicated.
  /// The file should start with the `MDMP` magic bytes.
  static const String typeMinidump = 'event.minidump';

  /// Apple crash report file that creates an error event and is symbolicated.
  static const String typeAppleCrashReport = 'event.applecrashreport';

  /// XML file containing UE4 crash meta data.
  /// During event ingestion, event contexts and extra fields are extracted from
  /// this file.
  static const String typeUnrealContext = 'unreal.context';

  /// Plain-text log file obtained from UE4 crashes.
  /// During event ingestion, the last logs are extracted into event
  /// breadcrumbs.
  static const String typeUnrealLogs = 'unreal.logs';

  static const String typeViewHierarchy = 'event.view_hierarchy';

  SentryAttachment.fromLoader({
    required ContentLoader loader,
    required this.filename,
    String? attachmentType,
    this.contentType,
    bool? addToTransactions,
  })  : _loader = loader,
        attachmentType = attachmentType ?? typeAttachmentDefault,
        addToTransactions = addToTransactions ?? false;

  /// Creates an [SentryAttachment] from a [Uint8List]
  SentryAttachment.fromUint8List(
    Uint8List bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
    bool? addToTransactions,
  }) : this.fromLoader(
          attachmentType: attachmentType,
          loader: () => bytes,
          filename: fileName,
          contentType: contentType,
          addToTransactions: addToTransactions,
        );

  /// Creates an [SentryAttachment] from a [List<int>]
  SentryAttachment.fromIntList(
    List<int> bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
    bool? addToTransactions,
  }) : this.fromLoader(
          attachmentType: attachmentType,
          loader: () => Uint8List.fromList(bytes),
          filename: fileName,
          contentType: contentType,
          addToTransactions: addToTransactions,
        );

  /// Creates an [SentryAttachment] from [ByteData]
  SentryAttachment.fromByteData(
    ByteData bytes,
    String fileName, {
    String? contentType,
    String? attachmentType,
    bool? addToTransactions,
  }) : this.fromLoader(
          attachmentType: attachmentType,
          loader: () => bytes.buffer.asUint8List(),
          filename: fileName,
          contentType: contentType,
          addToTransactions: addToTransactions,
        );

  SentryAttachment.fromScreenshotData(Uint8List bytes)
      : this.fromUint8List(bytes, 'screenshot.png',
            contentType: 'image/png',
            attachmentType: SentryAttachment.typeAttachmentDefault);

  SentryAttachment.fromViewHierrchy(SentryViewHierarchy sentryViewHierarchy)
      : this.fromLoader(
            loader: () => Uint8List.fromList(
                utf8JsonEncoder.convert(sentryViewHierarchy.toJson())),
            filename: 'view-hierarchy.json',
            contentType: 'application/json',
            attachmentType: SentryAttachment.typeViewHierarchy);

  /// Attachment type.
  /// Should be one of types given in [AttachmentType].
  final String attachmentType;

  /// Attachment content.
  /// Is loaded while sending this attachment.
  FutureOr<Uint8List> get bytes => _loader();

  final ContentLoader _loader;

  /// Attachment file name.
  final String filename;

  /// Attachment content type.
  /// Inferred by Sentry if it's not given.
  final String? contentType;

  /// If true, attachment should be added to every transaction.
  /// Defaults to false.
  final bool addToTransactions;
}
