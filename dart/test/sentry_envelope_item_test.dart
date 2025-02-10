import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  group('SentryEnvelopeItem', () {
    test('fromEvent', () async {
      final eventId = SentryId.newId();
      final sentryEvent = SentryEvent(eventId: eventId);
      final sut = SentryEnvelopeItem.fromEvent(sentryEvent);

      final expectedData = utf8.encode(jsonEncode(
        sentryEvent.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final actualData = await sut.dataFactory();

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.event);
      expect(actualData, expectedData);
    });

    test('fromEvent feedback', () async {
      final feedback = SentryFeedback(
        message: 'fixture-message',
      );
      final feedbackEvent = SentryEvent(
        type: 'feedback',
        contexts: Contexts(feedback: feedback),
        level: SentryLevel.info,
      );
      final sut = SentryEnvelopeItem.fromEvent(feedbackEvent);

      final expectedData = utf8.encode(jsonEncode(
        feedbackEvent.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final actualData = await sut.dataFactory();

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, 'feedback');
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

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.transaction);
      expect(actualData, expectedData);
    });

    test('fromClientReport', () async {
      final timestamp = DateTime(0);
      final discardedEvents = [
        DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)
      ];

      final cr = ClientReport(timestamp, discardedEvents);

      final sut = SentryEnvelopeItem.fromClientReport(cr);

      final expectedData = utf8.encode(jsonEncode(
        cr.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final actualData = await sut.dataFactory();

      expect(sut.header.contentType, 'application/json');
      expect(sut.header.type, SentryItemType.clientReport);
      expect(actualData, expectedData);
    });
  });
}
