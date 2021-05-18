import 'dart:convert';
import 'dart:io';

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

      final expectedHeaderJson = header.toJson();
      final expectedHeaderJsonSerialized = jsonEncode(expectedHeaderJson);

      final expectedItem = <int>[];
      await item.envelopeItemStream().forEach(expectedItem.addAll);
      final expectedItemSerialized = utf8.decode(expectedItem);

      final expected = utf8.encode(
          '$expectedHeaderJsonSerialized\n$expectedItemSerialized\n$expectedItemSerialized');

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

    test('item with binary payload', () async {
      // Attachment

      final length = () async {
        return 3535;
      };
      final dataFactory = () async {
        final file = File('test_resources/sentry.png');
        final bytes = await file.readAsBytes();
        return bytes;
      };
      final attachmentHeader = SentryEnvelopeItemHeader('attachment', length,
          contentType: 'image/png', fileName: 'sentry.png');
      final attachmentItem = SentryEnvelopeItem(attachmentHeader, dataFactory);

      // Envelope

      final eventId = SentryId.fromId('3b382f22ee67491f80f7dee18016a7b1');
      final sdkVersion = SdkVersion(name: 'test', version: 'version');
      final header = SentryEnvelopeHeader(eventId, sdkVersion);
      final envelope = SentryEnvelope(header, [attachmentItem]);

      final envelopeData = <int>[];
      await envelope.envelopeStream().forEach(envelopeData.addAll);

      final expectedEnvelopeFile =
          File('test_resources/envelope-with-image.envelope');
      final expectedEnvelopeData = await expectedEnvelopeFile.readAsBytes();

      expect(expectedEnvelopeData, envelopeData);
    });
  });
}
