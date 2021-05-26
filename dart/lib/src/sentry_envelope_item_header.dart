/// Header with item info about type and length of data in bytes.
class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(this.type, this.length,
      {this.contentType, this.fileName});

  /// Type of encoded data.
  final String type;

  /// The number of bytes of the encoded item JSON.
  final Future<int> Function() length;

  final String? contentType;

  final String? fileName;

  /// Item header encoded as JSON
  Future<Map<String, dynamic>> toJson() async {
    final json = <String, dynamic>{};
    if (contentType != null) {
      json['content_type'] = contentType;
    }
    if (fileName != null) {
      json['filename'] = fileName;
    }
    json['type'] = type;
    json['length'] = await length();
    return json;
  }
}
