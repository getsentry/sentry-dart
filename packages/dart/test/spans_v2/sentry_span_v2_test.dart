import 'package:sentry/sentry.dart';
import 'package:sentry/src/spans_v2/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
import '../mocks/mock_sentry_client.dart';
import '../mocks/mock_sentry_span_v2_factory.dart';
import '../test_utils.dart';

void main() {
  group('RecordingSentrySpanV2', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('end finishes the span', () {
      final span = fixture.createSpan(name: 'test-span');

      span.end();

      expect(span.endTimestamp, isNotNull);
      expect(span.isFinished, isTrue);
    });

    test('end sets current time by default', () {
      final span = fixture.createSpan(name: 'test-span');

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
      final span = fixture.createSpan(name: 'test-span');
      final endTime = DateTime.now().add(Duration(seconds: 5)).toUtc();

      span.end(endTimestamp: endTime);

      expect(span.endTimestamp, equals(endTime));
    });

    test('end sets endTimestamp as UTC', () {
      final span1 = fixture.createSpan(name: 'test-span');
      span1.end();
      expect(span1.endTimestamp!.isUtc, isTrue);

      final span2 = fixture.createSpan(name: 'test-span');
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
      var captureSpanCount = 0;
      final span = fixture.createSpan(
        name: 'test-span',
        onSpanEnded: (_) {
          captureSpanCount++;
        },
      );
      final firstEndTimestamp = DateTime.utc(2024, 1, 1);
      final secondEndTimestamp = DateTime.utc(2024, 1, 2);

      span.end(endTimestamp: firstEndTimestamp);
      span.end(endTimestamp: secondEndTimestamp);

      expect(span.endTimestamp, equals(firstEndTimestamp));
      expect(span.isFinished, isTrue);
      expect(captureSpanCount, 1);
    });

    test('setAttribute sets single attribute', () {
      final span = fixture.createSpan(name: 'test-span');

      final attributeValue = SentryAttribute.string('value');
      span.setAttribute('key', attributeValue);

      expect(span.attributes, equals({'key': attributeValue}));
    });

    test('setAttributes sets multiple attributes', () {
      final span = fixture.createSpan(name: 'test-span');

      final attributes = {
        'key1': SentryAttribute.string('value1'),
        'key2': SentryAttribute.int(42),
      };
      span.setAttributes(attributes);

      expect(span.attributes, equals(attributes));
    });

    test('setName sets span name', () {
      final span = fixture.createSpan(name: 'initial-name');

      span.name = 'updated-name';
      expect(span.name, equals('updated-name'));
    });

    test('setStatus sets span status', () {
      final span = fixture.createSpan(name: 'test-span');

      span.status = SentrySpanStatusV2.ok;
      expect(span.status, equals(SentrySpanStatusV2.ok));

      span.status = SentrySpanStatusV2.error;
      expect(span.status, equals(SentrySpanStatusV2.error));
    });

    test('parentSpan returns the parent span', () {
      final parent = fixture.createSpan(name: 'parent');
      final child = fixture.createSpan(name: 'child', parentSpan: parent);

      expect(child.parentSpan, equals(parent));
    });

    test('parentSpan returns null for root span', () {
      final span = fixture.createSpan(name: 'root');

      expect(span.parentSpan, isNull);
    });

    test('name returns the span name', () {
      final span = fixture.createSpan(name: 'my-span-name');

      expect(span.name, equals('my-span-name'));
    });

    test('spanId is created when span is created', () {
      final span = fixture.createSpan(name: 'test-span');

      expect(span.spanId.toString(), isNot(SpanId.empty().toString()));
    });

    group('segmentSpan', () {
      test('returns itself when parentSpan is null', () {
        final span = fixture.createSpan(name: 'root-span');

        expect(span.segmentSpan, same(span));
      });

      test('returns parent segmentSpan when parentSpan is set', () {
        final root = fixture.createSpan(name: 'root');
        final child = fixture.createSpan(name: 'child', parentSpan: root);

        expect(child.segmentSpan, same(root));
      });

      test('returns root segmentSpan for deeply nested spans', () {
        final root = fixture.createSpan(name: 'root');
        final child = fixture.createSpan(name: 'child', parentSpan: root);
        final grandchild =
            fixture.createSpan(name: 'grandchild', parentSpan: child);
        final greatGrandchild = fixture.createSpan(
            name: 'great-grandchild', parentSpan: grandchild);

        expect(grandchild.segmentSpan, same(root));
        expect(greatGrandchild.segmentSpan, same(root));
      });
    });

    group('traceId', () {
      test('uses traceId from factory', () {
        final expectedTraceId = SentryId.newId();
        final span =
            fixture.createSpan(name: 'test-span', traceId: expectedTraceId);

        expect(span.traceId, equals(expectedTraceId));
      });

      test('child span has same traceId as parent', () {
        final parent = fixture.createSpan(name: 'parent');
        final child = fixture.createSpan(name: 'child', parentSpan: parent);

        expect(child.traceId, equals(parent.traceId));
      });

      test(
          'child span inherits traceId from parent even with different traceId factory',
          () {
        final originalTraceId = SentryId.newId();
        final parent =
            fixture.createSpan(name: 'parent', traceId: originalTraceId);
        final parentTraceId = parent.traceId;

        // Create child span with a different traceId in the factory
        final newTraceId = SentryId.newId();
        final child = fixture.createSpan(
            name: 'child', parentSpan: parent, traceId: newTraceId);

        // Child should inherit from parent, not from the factory
        expect(child.traceId, equals(parentTraceId));
        expect(child.traceId, isNot(equals(newTraceId)));
      });

      test('traceId is set at construction time from factory', () {
        final originalTraceId = SentryId.newId();
        final span =
            fixture.createSpan(name: 'test-span', traceId: originalTraceId);

        // Span should have the original traceId
        expect(span.traceId, equals(originalTraceId));
      });
    });

    group('toJson', () {
      test('serializes basic span without parent', () {
        final span = fixture.createSpan(name: 'test-span');
        span.end();

        final json = span.toJson();

        expect(json['trace_id'], equals(span.traceId.toString()));
        expect(json['span_id'], equals(span.spanId.toString()));
        expect(json['name'], equals('test-span'));
        expect(json['is_segment'], isTrue);
        expect(json['status'], equals('ok'));
        expect(json['start_timestamp'], isA<double>());
        expect(json['end_timestamp'], isA<double>());
        expect(json.containsKey('parent_span_id'), isFalse);
      });

      test('serializes span with parent', () {
        final parent = fixture.createSpan(name: 'parent');
        final child = fixture.createSpan(name: 'child', parentSpan: parent);
        child.end();

        final json = child.toJson();

        expect(json['parent_span_id'], equals(parent.spanId.toString()));
        expect(json['is_segment'], isFalse);
      });

      test('serializes span with error status', () {
        final span = fixture.createSpan(name: 'test-span');
        span.status = SentrySpanStatusV2.error;
        span.end();

        final json = span.toJson();

        expect(json['status'], equals('error'));
      });

      test('serializes span with attributes', () {
        final span = fixture.createSpan(name: 'test-span');
        span.setAttribute('string_attr', SentryAttribute.string('value'));
        span.setAttribute('int_attr', SentryAttribute.int(42));
        span.setAttribute('bool_attr', SentryAttribute.bool(true));
        span.setAttribute('double_attr', SentryAttribute.double(3.14));
        span.end();

        final json = span.toJson();

        expect(json.containsKey('attributes'), isTrue);
        final attributes = json['attributes'] as Map<String, dynamic>;

        expect(attributes['string_attr'], {'value': 'value', 'type': 'string'});
        expect(attributes['int_attr'], {'value': 42, 'type': 'integer'});
        expect(attributes['bool_attr'], {'value': true, 'type': 'boolean'});
        expect(attributes['double_attr'], {'value': 3.14, 'type': 'double'});
      });

      test('does not include attributes key when no attributes set', () {
        final span = fixture.createSpan(name: 'test-span');
        span.end();

        final json = span.toJson();

        expect(json.containsKey('attributes'), isFalse);
      });

      test('end_timestamp is null when span is not finished', () {
        final span = fixture.createSpan(name: 'test-span');

        final json = span.toJson();

        expect(json['end_timestamp'], isNull);
      });

      test(
          'timestamps are serialized as unix seconds with microsecond precision',
          () {
        final span = fixture.createSpan(name: 'test-span');
        final customEndTime = DateTime.utc(2024, 6, 15, 12, 30, 45, 123, 456);
        span.end(endTimestamp: customEndTime);

        final json = span.toJson();

        final endTimestamp = json['end_timestamp'] as double;
        // 2024-06-15 12:30:45.123456 UTC in microseconds since epoch
        final expectedMicros = customEndTime.microsecondsSinceEpoch;
        final expectedSeconds = expectedMicros / 1000000;

        expect(endTimestamp, closeTo(expectedSeconds, 0.000001));
      });

      test('serializes updated name', () {
        final span = fixture.createSpan(name: 'original-name');
        span.name = 'updated-name';
        span.end();

        final json = span.toJson();

        expect(json['name'], equals('updated-name'));
      });
    });
  });

  group('NoOpSentrySpanV2', () {
    test('operations do not throw', () {
      const span = NoOpSentrySpanV2();

      // All operations should be no-ops and not throw
      span.end();
      span.end(endTimestamp: DateTime.now());
      span.setAttribute('key', SentryAttribute.string('value'));
      span.setAttributes({'key': SentryAttribute.string('value')});
      span.name = 'name';
      span.status = SentrySpanStatusV2.ok;
      span.status = SentrySpanStatusV2.error;
    });
  });

  group('UnsetSentrySpanV2', () {
    test('all APIs throw to prevent accidental use', () {
      const span = UnsetSentrySpanV2();

      expect(() => span.spanId, throwsA(isA<UnimplementedError>()));
      expect(() => span.name, throwsA(isA<UnimplementedError>()));
      expect(() => span.status, throwsA(isA<UnimplementedError>()));
      expect(() => span.parentSpan, throwsA(isA<UnimplementedError>()));
      expect(() => span.endTimestamp, throwsA(isA<UnimplementedError>()));
      expect(() => span.attributes, throwsA(isA<UnimplementedError>()));
      expect(() => span.isFinished, throwsA(isA<UnimplementedError>()));

      expect(() => span.name = 'foo', throwsA(isA<UnimplementedError>()));
      expect(() => span.status = SentrySpanStatusV2.ok,
          throwsA(isA<UnimplementedError>()));
      expect(() => span.setAttribute('k', SentryAttribute.string('v')),
          throwsA(isA<UnimplementedError>()));
      expect(() => span.setAttributes({'k': SentryAttribute.string('v')}),
          throwsA(isA<UnimplementedError>()));
      expect(() => span.end(), throwsA(isA<UnimplementedError>()));
    });
  });
}

class Fixture {
  final client = MockSentryClient();

  final options = defaultTestOptions();
  late final MockSentrySpanV2Factory spanFactory =
      MockSentrySpanV2Factory(options);

  Hub getHub({
    double? tracesSampleRate = 1.0,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    final hub = Hub(options)..bindClient(client);
    return hub;
  }

  MockHub getMockHub() => MockHub();

  /// Creates a [RecordingSentrySpanV2] for testing.
  RecordingSentrySpanV2 createSpan({
    required String name,
    RecordingSentrySpanV2? parentSpan,
    SentryId? traceId,
    void Function(RecordingSentrySpanV2)? onSpanEnded,
  }) =>
      spanFactory.createSpan(
        name: name,
        parent: parentSpan,
        traceId: traceId,
        onSpanEnded: onSpanEnded,
      );
}
