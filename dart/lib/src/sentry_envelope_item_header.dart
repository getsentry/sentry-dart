import 'sentry_item_type.dart';

class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(this.type, this.length,
      {this.contentType, this.fileName});

  final SentryItemType type;
  final Future<int> Function() length;

  final String? contentType;
  final String? fileName;

  Future<Map<String, dynamic>> toJson() async {
    final json = <String, dynamic>{};
    if (contentType != null) {
      json['content_type'] = contentType!;
    }
    json['type'] = type.toStringValue();
    json['length'] = await length();
    return json;
  }
}
