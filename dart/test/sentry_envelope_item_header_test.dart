import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItemHeader', () {
    test('serialize', () {
      final sut = SentryEnvelopeItemHeader(SentryItemType.event, 3, contentType: 'application/json');
      final expected = '{\"content_type\":\"application/json\",\"type\":\"event\",\"length\":3}';
      expect(sut.serialize(), expected);
    });
  });
}
