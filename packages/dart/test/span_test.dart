import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_span.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:sentry/src/protocol/unset_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('SimpleSpan', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('end finishes the span', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.end();

      expect(span.endTimestamp, isNotNull);
      expect(span.isFinished, isTrue);
    });

    test('end sets current time by default', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      final before = DateTime.now().toUtc();
      span.end();
      final after = DateTime.now().toUtc();

      expect(span.endTimestamp, isNotNull);
      expect(span.endTimestamp!.isAfter(before) || span.endTimestamp == before,
          isTrue,
          reason: 'endTimestamp should be >= time before end() was called');
      expect(span.endTimestamp!.isBefore(after) || span.endTimestamp == after,
          isTrue,
          reason: 'endTimestamp should be <= time after end() was called');
    });

    test('end with custom timestamp sets end time', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);
      final endTime = DateTime.now().add(Duration(seconds: 5)).toUtc();

      span.end(endTimestamp: endTime);

      expect(span.endTimestamp, equals(endTime));
    });

    test('end sets endTimestamp as UTC', () {
      final span1 = SimpleSpan(name: 'test-span');
      span1.end();
      expect(span1.endTimestamp!.isUtc, isTrue);

      final span2 = SimpleSpan(name: 'test-span');
      // Should transform non-utc time to utc
      span2.end(endTimestamp: DateTime.now());
      expect(span2.endTimestamp!.isUtc, isTrue);
    });

    test('end removes active span from scope', () {
      final hub = fixture.getHub();
      final span = hub.startSpan('test-span');
      expect(hub.scope.activeSpans.length, 1);
      expect(hub.scope.activeSpans.first, equals(span));

      span.end();

      expect(hub.scope.activeSpans, isEmpty);
    });

    test('end is idempotent once finished', () {
      final hub = fixture.getMockHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);
      final firstEndTimestamp = DateTime.utc(2024, 1, 1);
      final secondEndTimestamp = DateTime.utc(2024, 1, 2);

      span.end(endTimestamp: firstEndTimestamp);
      span.end(endTimestamp: secondEndTimestamp);

      expect(span.endTimestamp, equals(firstEndTimestamp));
      expect(span.isFinished, isTrue);
      expect(hub.captureSpanCalls.length, 1);
    });

    test('setAttribute sets single attribute', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      final attributeValue = SentryAttribute.string('value');
      span.setAttribute('key', attributeValue);

      expect(span.attributes, equals({'key': attributeValue}));
    });

    test('setAttributes sets multiple attributes', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      final attributes = {
        'key1': SentryAttribute.string('value1'),
        'key2': SentryAttribute.int(42),
      };
      span.setAttributes(attributes);

      expect(span.attributes, equals(attributes));
    });

    test('setName sets span name', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'initial-name', parentSpan: null, hub: hub);

      span.name = 'updated-name';
      expect(span.name, equals('updated-name'));
    });

    test('setStatus sets span status', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'test-span', parentSpan: null, hub: hub);

      span.status = SpanV2Status.ok;
      expect(span.status, equals(SpanV2Status.ok));

      span.status = SpanV2Status.error;
      expect(span.status, equals(SpanV2Status.error));
    });

    test('parentSpan returns the parent span', () {
      final hub = fixture.getHub();
      final parent = SimpleSpan(name: 'parent', parentSpan: null, hub: hub);
      final child = SimpleSpan(name: 'child', parentSpan: parent, hub: hub);

      expect(child.parentSpan, equals(parent));
    });

    test('parentSpan returns null for root span', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'root', parentSpan: null, hub: hub);

      expect(span.parentSpan, isNull);
    });

    test('name returns the span name', () {
      final hub = fixture.getHub();
      final span = SimpleSpan(name: 'my-span-name', parentSpan: null, hub: hub);

      expect(span.name, equals('my-span-name'));
    });

    test('spanId is created when span is created', () {
      final span = SimpleSpan(name: 'test-span');

      expect(span.spanId.toString(), isNot(SpanId.empty().toString()));
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
      span.name = 'name';
      span.status = SpanV2Status.ok;
      span.status = SpanV2Status.error;
      expect(span.toJson(), isEmpty);
    });
  });

  group('UnsetSpan', () {
    test('all APIs throw to prevent accidental use', () {
      const span = UnsetSpan();

      expect(() => span.spanId, throwsA(isA<UnimplementedError>()));
      expect(() => span.name, throwsA(isA<UnimplementedError>()));
      expect(() => span.status, throwsA(isA<UnimplementedError>()));
      expect(() => span.parentSpan, throwsA(isA<UnimplementedError>()));
      expect(() => span.endTimestamp, throwsA(isA<UnimplementedError>()));
      expect(() => span.attributes, throwsA(isA<UnimplementedError>()));
      expect(() => span.isFinished, throwsA(isA<UnimplementedError>()));

      expect(() => span.name = 'foo', throwsA(isA<UnimplementedError>()));
      expect(() => span.status = SpanV2Status.ok,
          throwsA(isA<UnimplementedError>()));
      expect(() => span.setAttribute('k', SentryAttribute.string('v')),
          throwsA(isA<UnimplementedError>()));
      expect(() => span.setAttributes({'k': SentryAttribute.string('v')}),
          throwsA(isA<UnimplementedError>()));
      expect(() => span.end(), throwsA(isA<UnimplementedError>()));
      expect(() => span.toJson(), throwsA(isA<UnimplementedError>()));
    });
  });
}

class Fixture {
  final client = MockSentryClient();

  final options = defaultTestOptions();

  Hub getHub({
    double? tracesSampleRate = 1.0,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    final hub = Hub(options)..bindClient(client);
    return hub;
  }

  MockHub getMockHub() => MockHub();
}
