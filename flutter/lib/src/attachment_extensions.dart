import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

extension AttachmentExtension on SentryAttachment {
  /// Creates an attachment from an asset out of a [AssetBundle].
  /// If no bundle is given, it's using the [rootBundle].
  /// Typically you want to use it like this:
  /// ```dart
  /// final attachment = Attachment.fromAsset(
  ///   'assets/foo_bar.txt',
  ///   bundle: DefaultAssetBundle.of(context),
  /// );
  /// ```
  static Future<SentryAttachment> fromAsset(
    String key, {
    AssetBundle? bundle,
    String? type,
    String? contentType,
  }) async {
    final data = await (bundle ?? rootBundle).load(key);
    final fileName = Uri.parse(key).pathSegments.last;

    return SentryAttachment.fromByteData(
      data,
      fileName,
      attachmentType: type,
      contentType: contentType,
    );
  }
}
