/// Header with item info about type and length of data in bytes.
class SentryEnvelopeItemHeader {
  SentryEnvelopeItemHeader(
    this.type,
    this.length, {
    this.contentType,
    this.fileName,
    this.attachmentType,
  });

  /// Type of encoded data.
  final String type;

  /// The number of bytes of the encoded item JSON.
  /// A negative number indicates an invalid envelope which should not be send
  /// to Sentry.io.
  final Future<int> Function() length;

  final String? contentType;

  final String? fileName;

  final String? attachmentType;

  /// Item header encoded as JSON
  Future<Map<String, dynamic>> toJson() async {
    final json = <String, dynamic>{
      if (contentType != null) 'content_type': contentType,
      if (fileName != null) 'filename': fileName,
      if (attachmentType != null) 'attachment_type': attachmentType,
      'type': type,
      'length': await length(),
    };

    return json;
  }
}
