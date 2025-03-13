import 'dart:async';
import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_transport.dart';
import 'test_utils.dart';

void main() {
  group('SentryClient beforeSendEvent', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('beforeSendEvent is called with correct event and hint', () async {
      final observer = _TestEventObserver();
      fixture.options.addBeforeSendEventObserver(observer);

      final client = fixture.getSut();
      final hint = Hint();
      final event = SentryEvent().copyWith(type: 'some random type');

      await client.captureEvent(event, hint: hint);

      expect(observer.inspectedEvent?.type, 'some random type');
      expect(observer.inspectedHint, same(hint));
    });

    test('beforeSendEvent is called for transactions', () async {
      final observer = _TestEventObserver();
      fixture.options.addBeforeSendEventObserver(observer);

      final client = fixture.getSut();
      final hint = Hint();
      final tracer = SentryTracer(
        SentryTransactionContext('name', 'op'),
        Sentry.currentHub,
      );
      final event = SentryTransaction(tracer);

      await client.captureEvent(event, hint: hint);

      expect(
          (observer.inspectedEvent as SentryTransaction).tracer.name, 'name');
      expect(
          (observer.inspectedEvent as SentryTransaction)
              .tracer
              .context
              .operation,
          'op');
      expect(observer.inspectedHint, same(hint));
    });

    test('beforeSendEvent is called after all other processors', () async {
      final processingOrder = <String>[];

      fixture.options.addEventProcessor(_TestEventProcessor(processingOrder));
      fixture.options.beforeSend = (event, hint) {
        processingOrder.add('beforeSend');
        return event;
      };

      fixture.options
          .addBeforeSendEventObserver(_TestOrderObserver(processingOrder));

      final client = fixture.getSut();
      final event = SentryEvent();

      await client.captureEvent(event);

      expect(
          processingOrder, ['eventProcessor', 'beforeSend', 'beforeSendEvent']);
    });
  });
}

Future<SentryEvent> eventFromEnvelope(SentryEnvelope envelope) async {
  final data = await envelope.items.first.dataFactory();
  final utf8Data = utf8.decode(data);
  final envelopeItemJson = jsonDecode(utf8Data);
  return SentryEvent.fromJson(envelopeItemJson as Map<String, dynamic>);
}

class Fixture {
  final options = defaultTestOptions();

  SentryClient getSut() {
    options.transport = MockTransport();

    return SentryClient(options);
  }
}

class _TestEventObserver implements BeforeSendEventObserver {
  SentryEvent? inspectedEvent;
  Hint? inspectedHint;

  @override
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint) {
    inspectedEvent = event;
    inspectedHint = hint;
  }
}

class _TestEventProcessor extends EventProcessor {
  _TestEventProcessor(this._processingOrder);

  final List<String> _processingOrder;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) {
    _processingOrder.add('eventProcessor');
    return event;
  }
}

class _TestOrderObserver extends BeforeSendEventObserver {
  final List<String> _processingOrder;

  _TestOrderObserver(this._processingOrder);

  @override
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint) {
    _processingOrder.add('beforeSendEvent');
  }
}
