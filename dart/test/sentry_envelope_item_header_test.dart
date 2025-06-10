import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItemHeader', () {
    test('serialize', () async {
      final sut = SentryEnvelopeItemHeader(SentryItemType.event,
          itemCount: 3, contentType: 'application/json');
      final expected = <String, dynamic>{
        'item_count': 3,
        'content_type': 'application/json',
        'type': 'event',
        'length': 3
      };
      expect(await sut.toJson(3), expected);
    });
  });
}
