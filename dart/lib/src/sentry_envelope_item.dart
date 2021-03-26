import 'dart:typed_data';

import 'sentry_envelope_header.dart';

class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.data);
  
  final SentryEnvelopeHeader header;
  final ByteData data;
}
