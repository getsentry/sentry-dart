import 'dart:convert';

import 'sentry_item_type.dart';

class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(this.type, this.length,
      {this.contentType, this.fileName});

  final SentryItemType type;
  final int length;

  final String? contentType;
  final String? fileName;

  String serialize() {
    final serializedMap = <String, dynamic>{};
    if (contentType != null) {
      serializedMap['content_type'] = contentType!;
    }
    serializedMap['type'] = type.toStringValue();
    serializedMap['length'] = length;
    return jsonEncode(serializedMap);
  }
}
