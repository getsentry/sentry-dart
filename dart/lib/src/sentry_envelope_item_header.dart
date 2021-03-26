import 'sentry_item_type.dart';

class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(
      this.contentType, this.fileName, this.type, this.length);

  final String? contentType;
  final String? fileName;
  final SentryItemType type;
  final int length;
}
