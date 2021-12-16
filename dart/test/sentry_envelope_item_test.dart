import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/utils.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  group('SentryEnvelopeItem', () {
    test('serialize', () async {
      final header = SentryEnvelopeItemHeader(SentryItemType.event, () async {
        return 9;
      }, contentType: 'application/json');

      final dataFactory = () async {
        return utf8.encode('{fixture}');
      };

      final sut = SentryEnvelopeItem(header, dataFactory);

      final headerJson = await header.toJson();
      final headerJsonEncoded = jsonEncode(
        headerJson,
        toEncodable: jsonSerializationFallback,
      );
      final expected = utf8.encode('$headerJsonEncoded\n{fixture}');

      final actualItem = await sut.envelopeItemStream();

      expect(actualItem, expected);
    });

    test('fromEvent', () async {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sut = SentryEnvelopeItem.fromEvent(sentryEvent);

      final expectedData = utf8.encode(jsonEncode(
        sentryEvent.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final actualData = await sut.dataFactory();

      final expectedLength = expectedData.length;
      final actualLength = await sut.header.length();

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.event);
      expect(actualLength, expectedLength);
      expect(actualData, expectedData);
    });

    test('fromTransaction', () async {
      final context = SentryTransactionContext(
        'name',
        'op',
      );
      final tracer = SentryTracer(context, MockHub());
      final tr = SentryTransaction(tracer);
      tr.contexts.device = SentryDevice(
        orientation: SentryOrientation.landscape,
      );

      final sut = SentryEnvelopeItem.fromTransaction(tr);

      final expectedData = utf8.encode(jsonEncode(
        tr.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final actualData = await sut.dataFactory();

      final expectedLength = expectedData.length;
      final actualLength = await sut.header.length();

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.transaction);
      expect(actualLength, expectedLength);
      expect(actualData, expectedData);
    });
  });
}
