/// Header with item info about type and length of data in bytes.
class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(
    this.type, {
    this.contentType,
    this.fileName,
    this.attachmentType,
  });

  /// Type of encoded data.
  final String type;

  final String? contentType;

  final String? fileName;

  final String? attachmentType;

  /// Item header encoded as JSON
  Future<Map<String, dynamic>> toJson(int length) async {
    return {
      if (contentType != null) 'content_type': contentType,
      if (fileName != null) 'filename': fileName,
      if (attachmentType != null) 'attachment_type': attachmentType,
      'type': type,
      'length': length,
    };
  }
}
