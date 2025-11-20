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
import 'test_utils.dart';

void main() {
  group('SentryEnvelope', () {
    Future<String> serializedItem(SentryEnvelopeItem item) async {
      final expectedItemData = await item.dataFactory();
      final expectedItemHeader = utf8JsonEncoder
          .convert(await item.header.toJson(expectedItemData.length));
      final newLine = utf8.encode('\n');
      final expectedItem = <int>[
        ...expectedItemHeader,
        ...newLine,
        ...expectedItemData
      ];
      return utf8.decode(expectedItem);
    }

    test('serialize', () async {
      final eventId = SentryId.newId();

      final itemHeader = SentryEnvelopeItemHeader(SentryItemType.event,
          contentType: 'application/json');

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

      final expectedItemSerialized = await serializedItem(item);

      final expected = utf8.encode(
          '$expectedHeaderJsonSerialized\n$expectedItemSerialized\n$expectedItemSerialized');

      final envelopeData = <int>[];
      await sut
          .envelopeStream(defaultTestOptions())
          .forEach(envelopeData.addAll);
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

      final actualItem = await sut.items[0].dataFactory();
      final expectedItem = await expectedEnvelopeItem.dataFactory();
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

      final actualItem = await sut.items[0].dataFactory();
      final expectedItem = await expectedEnvelopeItem.dataFactory();
      expect(actualItem, expectedItem);
    });

    test('fromLogs', () async {
      final logs = [
        SentryLog(
          timestamp: DateTime.now(),
          traceId: SentryId.newId(),
          level: SentryLogLevel.info,
          body: 'test',
          attributes: {
            'test': SentryAttribute.string('test'),
          },
        ),
        SentryLog(
          timestamp: DateTime.now(),
          traceId: SentryId.newId(),
          level: SentryLogLevel.info,
          body: 'test2',
          attributes: {
            'test2': SentryAttribute.int(9001),
          },
        ),
      ];

      final sdkVersion = SdkVersion(
        name: 'fixture-name',
        version: 'fixture-version',
      );

      final sut = SentryEnvelope.fromLogs(logs, sdkVersion);

      expect(sut.header.sdkVersion, sdkVersion);

      final expectedItem = SentryEnvelopeItem.fromLogs(logs);
      final expectedItemData = await expectedItem.dataFactory();
      final actualItemData = await sut.items[0].dataFactory();

      expect(actualItemData, expectedItemData);
    });

    test('fromLogsData', () async {
      final encodedLogs = [
        utf8.encode(
            '{"timestamp":"2023-01-01T00:00:00.000Z","level":"info","body":"test1","attributes":{}}'),
        utf8.encode(
            '{"timestamp":"2023-01-01T00:00:01.000Z","level":"info","body":"test2","attributes":{}}'),
      ];

      final sdkVersion =
          SdkVersion(name: 'fixture-name', version: 'fixture-version');
      final sut = SentryEnvelope.fromLogsData(encodedLogs, sdkVersion);

      expect(sut.header.eventId, null);
      expect(sut.header.sdkVersion, sdkVersion);
      expect(sut.items.length, 1);

      final expectedEnvelopeItem = SentryEnvelopeItem.fromLogsData(
        // The envelope should create the final payload with {"items": [...]} wrapper
        utf8.encode('{"items":[') +
            encodedLogs[0] +
            utf8.encode(',') +
            encodedLogs[1] +
            utf8.encode(']}'),
        2, // logsCount
      );

      expect(sut.items[0].header.contentType,
          expectedEnvelopeItem.header.contentType);
      expect(sut.items[0].header.type, expectedEnvelopeItem.header.type);
      expect(sut.items[0].header.itemCount, 2);

      final actualItem = await sut.items[0].dataFactory();
      final expectedItem = await expectedEnvelopeItem.dataFactory();
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
          .envelopeStream(defaultTestOptions()..maxAttachmentSize = 1)
          .forEach(sutEnvelopeData.addAll);

      final envelopeData = <int>[];
      await expectedEnvelopeItem
          .envelopeStream(defaultTestOptions())
          .forEach(envelopeData.addAll);

      expect(sutEnvelopeData, envelopeData);
    });

    test('ignore throwing envelope items', () async {
      final eventId = SentryId.newId();

      final itemHeader = SentryEnvelopeItemHeader(SentryItemType.event,
          contentType: 'application/json');
      final dataFactory = () async {
        return utf8.encode('{fixture}');
      };
      final dataFactoryThrowing = () async {
        throw Exception('Exception in data factory.');
      };

      final item = SentryEnvelopeItem(itemHeader, dataFactory);
      final throwingItem = SentryEnvelopeItem(itemHeader, dataFactoryThrowing);

      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final header = SentryEnvelopeHeader(
        eventId,
        null,
        traceContext: context,
      );
      final sut = SentryEnvelope(header, [item, throwingItem]);

      final expectedHeaderJson = header.toJson();
      final expectedHeaderJsonSerialized = jsonEncode(
        expectedHeaderJson,
        toEncodable: jsonSerializationFallback,
      );

      final expectedItemSerialized = await serializedItem(item);

      final expected =
          utf8.encode('$expectedHeaderJsonSerialized\n$expectedItemSerialized');

      final options = defaultTestOptions();
      options.automatedTestMode = false; // Test if throwing item is ignored.
      final envelopeData = <int>[];
      await sut.envelopeStream(options).forEach(envelopeData.addAll);
      expect(envelopeData, expected);
    });

    // This test passes if no exceptions are thrown, thus no asserts.
    // This is a test for https://github.com/getsentry/sentry-dart/issues/523
    test('serialize with non-serializable class', () async {
      // ignore: deprecated_member_use_from_same_package
      final event = SentryEvent(extra: {'non-encodable': NonEncodable()});
      final sut = SentryEnvelope.fromEvent(
        event,
        SdkVersion(
          name: 'test',
          version: '1',
        ),
        dsn: fakeDsn,
      );

      final _ = sut.envelopeStream(defaultTestOptions()).map((e) => e);
    });
  });
}

class NonEncodable {}
