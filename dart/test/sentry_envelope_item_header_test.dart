import 'dart:convert';

import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItemHeader', () {
    test('serialize', () async {
      final sut = SentryEnvelopeItemHeader(SentryItemType.event, () async { return 3; },
          contentType: 'application/json');
      final expected = utf8.encode(
          '{\"content_type\":\"application/json\",\"type\":\"event\",\"length\":3}');
      expect(await sut.serialize(), expected);
    });
  });
}
