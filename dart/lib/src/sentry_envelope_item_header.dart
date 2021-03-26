import 'sentry_item_type.dart';

class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(this.type, this.length,
      {this.contentType, this.fileName});

  final SentryItemType type;
  final int length;

  final String? contentType;
  final String? fileName;
}
