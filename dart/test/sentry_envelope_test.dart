import 'dart:convert';
import 'dart:typed_data';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  group('SentryEnvelope', () {
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

      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final header = SentryEnvelopeHeader(
        eventId,
        null,
        traceContext: context,
      );
      final sut = SentryEnvelope(header, [item, item]);

      final expectedHeaderJson = header.toJson();
      final expectedHeaderJsonSerialized = jsonEncode(
        expectedHeaderJson,
        toEncodable: jsonSerializationFallback,
      );

      final expectedItem = await item.envelopeItemStream();
      final expectedItemSerialized = utf8.decode(expectedItem);

      final expected = utf8.encode(
          '$expectedHeaderJsonSerialized\n$expectedItemSerialized\n$expectedItemSerialized');

      final envelopeData = <int>[];
      await sut.envelopeStream(SentryOptions()).forEach(envelopeData.addAll);
      expect(envelopeData, expected);
    });

    test('fromEvent', () async {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final sut = SentryEnvelope.fromEvent(
        sentryEvent,
        sdkVersion,
        dsn: fakeDsn,
        traceContext: context,
      );

      final expectedEnvelopeItem = SentryEnvelopeItem.fromEvent(sentryEvent);

      expect(sut.header.eventId, eventId);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.header.traceContext, context);
      expect(sut.header.dsn, fakeDsn);
      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(await sut.items[0].header.length(),
          await expectedEnvelopeItem.header.length());

      final actualItem = await sut.items[0].envelopeItemStream();

      final expectedItem = await expectedEnvelopeItem.envelopeItemStream();

      expect(actualItem, expectedItem);
    });

    test('fromTransaction', () async {
      final context = SentryTransactionContext(
        'name',
        'op',
      );
      final tracer = SentryTracer(context, MockHub());
      final tr = SentryTransaction(tracer);

      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final traceContext = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final sut = SentryEnvelope.fromTransaction(
        tr,
        sdkVersion,
        dsn: fakeDsn,
        traceContext: traceContext,
      );

      final expectedEnvelopeItem = SentryEnvelopeItem.fromTransaction(tr);

      expect(sut.header.eventId, tr.eventId);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.header.traceContext, traceContext);
      expect(sut.header.dsn, fakeDsn);
      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(await sut.items[0].header.length(),
          await expectedEnvelopeItem.header.length());

      final actualItem = await sut.items[0].envelopeItemStream();

      final expectedItem = await expectedEnvelopeItem.envelopeItemStream();

      expect(actualItem, expectedItem);
    });

    test('fromUserFeedback', () async {
      final eventId = SentryId.newId();
      final userFeedback = SentryUserFeedback(
          eventId: eventId, name: 'name', email: 'email', comments: 'comments');
      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final sut = SentryEnvelope.fromUserFeedback(
        userFeedback,
        sdkVersion,
        dsn: fakeDsn,
      );

      final expectedEnvelopeItem =
          SentryEnvelopeItem.fromUserFeedback(userFeedback);

      expect(sut.header.eventId, eventId);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.header.dsn, fakeDsn);
      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(await sut.items[0].header.length(),
          await expectedEnvelopeItem.header.length());

      final actualItem = await sut.items[0].envelopeItemStream();

      final expectedItem = await expectedEnvelopeItem.envelopeItemStream();

      expect(actualItem, expectedItem);
    });

    test('fromMetrics', () async {
      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final sut = SentryEnvelope.fromMetrics(
        fakeMetrics,
        sdkVersion,
        dsn: fakeDsn,
      );

      final expectedEnvelopeItem = SentryEnvelopeItem.fromMetrics(fakeMetrics);

      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.header.dsn, fakeDsn);
      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(await sut.items[0].header.length(),
          await expectedEnvelopeItem.header.length());

      final actualItem = await sut.items[0].envelopeItemStream();

      final expectedItem = await expectedEnvelopeItem.envelopeItemStream();

      expect(actualItem, expectedItem);
    });

    test('max attachment size', () async {
      final attachment = SentryAttachment.fromLoader(
        loader: () => Uint8List.fromList([1, 2, 3, 4]),
        filename: 'test.txt',
      );

      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');

      final sut = SentryEnvelope.fromEvent(
        sentryEvent,
        sdkVersion,
        dsn: fakeDsn,
        attachments: [attachment],
      );

      final expectedEnvelopeItem = SentryEnvelope.fromEvent(
        sentryEvent,
        sdkVersion,
        dsn: fakeDsn,
      );

      final sutEnvelopeData = <int>[];
      await sut
          .envelopeStream(SentryOptions()..maxAttachmentSize = 1)
          .forEach(sutEnvelopeData.addAll);

      final envelopeData = <int>[];
      await expectedEnvelopeItem
          .envelopeStream(SentryOptions())
          .forEach(envelopeData.addAll);

      expect(sutEnvelopeData, envelopeData);
    });

    // This test passes if no exceptions are thrown, thus no asserts.
    // This is a test for https://github.com/getsentry/sentry-dart/issues/523
    test('serialize with non-serializable class', () async {
      // ignore: deprecated_member_use_from_same_package
      final event = SentryEvent(extra: {'non-ecodable': NonEncodable()});
      final sut = SentryEnvelope.fromEvent(
        event,
        SdkVersion(
          name: 'test',
          version: '1',
        ),
        dsn: fakeDsn,
      );

      final _ = sut.envelopeStream(SentryOptions()).map((e) => e);
    });
  });
}

class NonEncodable {}
