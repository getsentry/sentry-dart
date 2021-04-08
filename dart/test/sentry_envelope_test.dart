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
    test('serialize', () async {
      final eventId = SentryId.newId();

      final itemHeader =
          SentryEnvelopeItemHeader(SentryItemType.event, () async {
        return 9;
      }, contentType: 'application/json');

      final dataFactory = () async {
        return utf8.encode('{fixture}');
      };

      final item = SentryEnvelopeItem(itemHeader, dataFactory);

      final header = SentryEnvelopeHeader(eventId, null);
      final sut = SentryEnvelope(header, [item, item]);

      final expectesHeaderJson = header.toJson();
      final expectesHeaderJsonSerialized = jsonEncode(expectesHeaderJson);

      final expectedItem = <int>[];
      await item.envelopeItemStream().forEach(expectedItem.addAll);
      final expectedItemSerialized = utf8.decode(expectedItem);

      final expected = utf8.encode(
          '$expectesHeaderJsonSerialized\n$expectedItemSerialized\n$expectedItemSerialized');

      final envelopeData = <int>[];
      await sut.envelopeStream().forEach(envelopeData.addAll);
      expect(envelopeData, expected);
    });

    test('fromEvent', () async {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final sut = SentryEnvelope.fromEvent(sentryEvent, sdkVersion);

      final expectedEnvelopeItem = SentryEnvelopeItem.fromEvent(sentryEvent);

      expect(sut.header.eventId, eventId);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(await sut.items[0].header.length(),
          await expectedEnvelopeItem.header.length());

      final actualItem = <int>[];
      await sut.items[0].envelopeItemStream().forEach(actualItem.addAll);

      final expectedItem = <int>[];
      await expectedEnvelopeItem
          .envelopeItemStream()
          .forEach(expectedItem.addAll);

      expect(actualItem, expectedItem);
    });
  });
}
