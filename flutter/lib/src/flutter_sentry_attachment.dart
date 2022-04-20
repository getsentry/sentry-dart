import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

class FlutterSentryAttachment extends SentryAttachment {
  /// Creates an attachment from an asset out of a [AssetBundle].
  /// If no bundle is given, it's using the [rootBundle].
  /// Typically you want to use it like this:
  /// ```dart
  /// final attachment = Attachment.fromAsset(
  ///   'assets/foo_bar.txt',
  ///   bundle: DefaultAssetBundle.of(context),
  /// );
  /// ```
  FlutterSentryAttachment.fromAsset(
    String key, {
    String? filename,
    AssetBundle? bundle,
    String? type,
    String? contentType,
    bool? addToTransactions,
  }) : super.fromLoader(
          loader: () async {
            final data = await (bundle ?? rootBundle).load(key);
            return data.buffer.asUint8List();
          },
          filename: filename ?? Uri.parse(key).pathSegments.last,
          attachmentType: type,
          contentType: contentType,
          addToTransactions: addToTransactions,
        );
}
