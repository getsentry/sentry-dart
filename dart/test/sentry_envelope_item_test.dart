import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItem', () {
    test('serialize', () {
      final header = SentryEnvelopeItemHeader(SentryItemType.event, 9,
          contentType: 'application/json');
      final sut = SentryEnvelopeItem(
          header, [123, 102, 105, 120, 116, 117, 114, 101, 125]); // {fixture}

      final expected = '${header.serialize()}\n{fixture}';
      expect(sut.serialize(), expected);
    });

    test('fromEvent', () {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sut = SentryEnvelopeItem.fromEvent(sentryEvent);

      final expectedData = utf8.encode(jsonEncode(sentryEvent.toJson()));

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.event);
      expect(sut.header.length, expectedData.length);
      expect(sut.data, expectedData);
    });
  });
}
