import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/telemetry_processing/single_envelope_builder.dart';
import 'package:sentry/src/telemetry_processing/span_envelope_builder.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_item.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_hub.dart';
import '../test_utils.dart';

void main() {
  late _Fixture fixture;

  setUp(() {
    fixture = _Fixture();
  });

  group('SingleEnvelopeBuilder', () {
    test('build returns empty list when given empty input', () {
      final builder = SingleEnvelopeBuilder<MockTelemetryItem>(
        (items) => throw StateError('Should not be called'),
      );

      final result = builder.build([]);

      expect(result, isEmpty);
    });

    test('build returns single envelope containing all items', () {
      List<EncodedTelemetryItem<MockTelemetryItem>>? receivedItems;
      final mockEnvelope = fixture.createMockEnvelope();

      final builder = SingleEnvelopeBuilder<MockTelemetryItem>((items) {
        receivedItems = items;
        return mockEnvelope;
      });

      final item1 = fixture.createEncodedItem(MockTelemetryItem(), [1, 2, 3]);
      final item2 = fixture.createEncodedItem(MockTelemetryItem(), [4, 5, 6]);

      final result = builder.build([item1, item2]);

      expect(result, hasLength(1));
      expect(result.first, same(mockEnvelope));
      expect(receivedItems, hasLength(2));
      expect(receivedItems, contains(item1));
      expect(receivedItems, contains(item2));
    });
  });

  group('LogEnvelopeBuilder', () {
    test('creates envelope with correct SDK and encoded logs', () async {
      final builder = LogEnvelopeBuilder(fixture.options);

      final log1 = fixture.createLog('log 1');
      final log2 = fixture.createLog('log 2');
      final encoded1 = utf8.encode('{"body":"log 1"}');
      final encoded2 = utf8.encode('{"body":"log 2"}');

      final result = builder.build([
        fixture.createEncodedItem(log1, encoded1),
        fixture.createEncodedItem(log2, encoded2),
      ]);

      expect(result, hasLength(1));

      final envelope = result.first;
      expect(envelope.header.sdkVersion, fixture.options.sdk);
      expect(envelope.items, hasLength(1));

      final envelopeItem = envelope.items.first;
      expect(envelopeItem.header.type, 'log');
      expect(envelopeItem.header.itemCount, 2);
    });
  });

  group('SpanEnvelopeBuilder', () {
    test('build returns empty list when given empty input', () {
      final builder = SpanEnvelopeBuilder(fixture.options);

      final result = builder.build([]);

      expect(result, isEmpty);
    });

    test('groups spans with same segment into single envelope', () {
      final builder = SpanEnvelopeBuilder(fixture.options);

      // Create root span and child span (same segment)
      final rootSpan = fixture.createRootSpan('root');
      final childSpan = fixture.createChildSpan('child', rootSpan);

      final result = builder.build([
        fixture.createEncodedSpan(rootSpan),
        fixture.createEncodedSpan(childSpan),
      ]);

      expect(result, hasLength(1));

      final envelope = result.first;
      expect(envelope.items, hasLength(1));
      expect(envelope.items.first.header.itemCount, 2);
    });

    test('creates separate envelopes for spans with different segments', () {
      final builder = SpanEnvelopeBuilder(fixture.options);

      // Create two separate root spans (different segments)
      final rootSpan1 = fixture.createRootSpan('root1');
      final rootSpan2 = fixture.createRootSpan('root2');

      final result = builder.build([
        fixture.createEncodedSpan(rootSpan1),
        fixture.createEncodedSpan(rootSpan2),
      ]);

      expect(result, hasLength(2));
      expect(result[0].items.first.header.itemCount, 1);
      expect(result[1].items.first.header.itemCount, 1);
    });

    test('creates separate envelopes for spans with different traceIds', () {
      final builder = SpanEnvelopeBuilder(fixture.options);

      // Create two spans with same spanId but different traceIds
      final sharedSpanId = SpanId.newId();
      final span1 = fixture.createRootSpan('span1',
          traceId: SentryId.newId(), spanId: sharedSpanId);
      final span2 = fixture.createRootSpan('span2',
          traceId: SentryId.newId(), spanId: sharedSpanId);

      final result = builder.build([
        fixture.createEncodedSpan(span1),
        fixture.createEncodedSpan(span2),
      ]);

      // Different traceIds should result in separate envelopes
      expect(result, hasLength(2));
    });

    test('envelope contains correct trace context', () {
      fixture.options.release = 'test-release@1.0.0';
      fixture.options.environment = 'test-env';
      final builder = SpanEnvelopeBuilder(fixture.options);

      final rootSpan = fixture.createRootSpan('root');
      final result = builder.build([fixture.createEncodedSpan(rootSpan)]);

      expect(result, hasLength(1));

      final envelope = result.first;
      final traceContext = envelope.header.traceContext;

      expect(traceContext, isNotNull);
      expect(traceContext!.traceId, rootSpan.segmentSpan.traceId);
      expect(traceContext.publicKey, fixture.options.parsedDsn.publicKey);
      expect(traceContext.release, 'test-release@1.0.0');
      expect(traceContext.environment, 'test-env');
    });
  });
}

class _Fixture {
  final hub = MockHub();
  late SentryOptions options;

  _Fixture() {
    options = defaultTestOptions();
  }

  SentryLog createLog(String body) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
  }

  EncodedTelemetryItem<T> createEncodedItem<T extends TelemetryItem>(
    T item,
    List<int> encoded,
  ) {
    return EncodedTelemetryItem(item, encoded);
  }

  EncodedTelemetryItem<Span> createEncodedSpan(Span span) {
    final encoded = utf8.encode(json.encode(span.toJson()));
    return EncodedTelemetryItem(span, encoded);
  }

  Span createRootSpan(String name, {SentryId? traceId, SpanId? spanId}) {
    return MockSpan(
      name: name,
      traceId: traceId ?? SentryId.newId(),
      spanId: spanId ?? SpanId.newId(),
      parentSpan: null,
    );
  }

  Span createChildSpan(String name, Span parent) {
    return MockSpan(
      name: name,
      traceId: parent.traceId,
      spanId: SpanId.newId(),
      parentSpan: parent,
    );
  }

  SentryEnvelope createMockEnvelope() {
    return SentryEnvelope(
      SentryEnvelopeHeader(null, options.sdk),
      [],
    );
  }
}
