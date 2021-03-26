import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItem', () {
    test('serialize', () {
      final eventId = SentryId.newId();

      final itemHeader = SentryEnvelopeItemHeader(SentryItemType.event, 9,
          contentType: 'application/json');
      final item =
          SentryEnvelopeItem(itemHeader, utf8.encode('{fixture}')); // {fixture}

      final header = SentryEnvelopeHeader(eventId, null);
      final sut = SentryEnvelope(header, [item, item]);

      final expected =
          '${header.serialize()}\n${itemHeader.serialize()}\n{fixture}\n${itemHeader.serialize()}\n{fixture}';
      expect(sut.serialize(), expected);
    });

    test('fromEvent', () {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sdkVersion = SdkVersion(
        name: 'fixture-name',
        version: 'fixture-version'
      );
      final sut = SentryEnvelope.fromEvent(sentryEvent, sdkVersion);

      final expectedEnvelopeItem = SentryEnvelopeItem.fromEvent(sentryEvent);

      expect(sut.header.eventId, eventId);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.items[0].header.contentType, expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(sut.items[0].header.length, expectedEnvelopeItem.header.length);
      expect(sut.items[0].data, expectedEnvelopeItem.data);
    });
  });
}
