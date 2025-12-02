import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_span.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('SimpleSpan', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('end finishes the span', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      // Should not throw
      span.end();
      // TODO: verify span is finished once SimpleSpan implements it
    });

    test('end with custom timestamp sets end time', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);
      final endTime = DateTime.now().add(Duration(seconds: 5));

      span.end(endTimestamp: endTime);
      // TODO: verify end timestamp once SimpleSpan implements it
    });

    test('setAttribute sets single attribute', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.setAttribute('key', SentryAttribute.string('value'));
      // TODO: verify attribute once SimpleSpan implements it
    });

    test('setAttributes sets multiple attributes', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.setAttributes({
        'key1': SentryAttribute.string('value1'),
        'key2': SentryAttribute.int(42),
      });
      // TODO: verify attributes once SimpleSpan implements it
    });

    test('setName sets span name', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'initial-name', parentSpan: null, hub: hub);

      span.setName('updated-name');
      // TODO: verify name once SimpleSpan implements it
    });

    test('setStatus sets span status to ok', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.setStatus(SpanV2Status.ok);
      // TODO: verify status once SimpleSpan implements it
    });

    test('setStatus sets span status to error', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.setStatus(SpanV2Status.error);
      // TODO: verify status once SimpleSpan implements it
    });

    test('parentSpan returns the parent span', () {
      final hub = fixture.getSut();
      final parent = SimpleSpan(name: 'parent', parentSpan: null, hub: hub);
      final child = SimpleSpan(name: 'child', parentSpan: parent, hub: hub);

      expect(child.parentSpan, equals(parent));
    });

    test('parentSpan returns null for root span', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'root', parentSpan: null, hub: hub);

      expect(span.parentSpan, isNull);
    });

    test('name returns the span name', () {
      final hub = fixture.getSut();
      final span = SimpleSpan(name: 'my-span-name', parentSpan: null, hub: hub);

      expect(span.name, equals('my-span-name'));
    });
  });

  group('NoOpSpan', () {
    test('NoOpSpan operations do not throw', () {
      const span = NoOpSpan();

      // All operations should be no-ops and not throw
      span.end();
      span.end(endTimestamp: DateTime.now());
      span.setAttribute('key', SentryAttribute.string('value'));
      span.setAttributes({'key': SentryAttribute.string('value')});
      span.setName('name');
      span.setStatus(SpanV2Status.ok);
      span.setStatus(SpanV2Status.error);
      expect(span.toJson(), isEmpty);
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = defaultTestOptions();

  Hub getSut({
    double? tracesSampleRate = 1.0,
  }) {
    options.tracesSampleRate = tracesSampleRate;

    final hub = Hub(options);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }
}

