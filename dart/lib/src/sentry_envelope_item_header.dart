import 'dart:convert';

import 'sentry_item_type.dart';

class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(this.type, this.length,
      {this.contentType, this.fileName});

  final SentryItemType type;
  final Future<int> Function() length;

  final String? contentType;
  final String? fileName;

  Future<List<int>> serialize() async {
    final serializedMap = <String, dynamic>{};
    if (contentType != null) {
      serializedMap['content_type'] = contentType!;
    }
    serializedMap['type'] = type.toStringValue();
    serializedMap['length'] = await length();
    return utf8.encode(jsonEncode(serializedMap));
  }
}
