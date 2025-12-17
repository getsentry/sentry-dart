import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/telemetry_processing/envelope_builder.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer_policy.dart';
import 'package:test/test.dart';

import '../mocks/mock_json_encodable.dart';
import '../mocks/mock_transport.dart';

void main() {
  group('InMemoryTelemetryBuffer', () {
    late _Fixture fixture;

    setUp(() {
      fixture = _Fixture();
    });

    test('items are flushed after timeout', () async {
      final flushTimeout = Duration(milliseconds: 1);
      final buffer = fixture.getSut(
        policy: TelemetryBufferConfig(flushTimeout: flushTimeout),
      );

      buffer.add(MockJsonEncodable('item1'));
      buffer.add(MockJsonEncodable('item2'));

      expect(fixture.mockTransport.envelopes.length, 0);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('items exceeding max size are flushed immediately', () async {
      // Each item encodes to ~14 bytes ({"id":"item1"}), so 20 bytes triggers flush on 2nd item
      final buffer = fixture.getSut(
        policy: TelemetryBufferConfig(maxBufferSizeBytes: 20),
      );

      buffer.add(MockJsonEncodable('item1'));
      expect(fixture.mockTransport.envelopes.length, 0);

      buffer.add(MockJsonEncodable('item2'));

      // Wait briefly for async flush
      await Future.delayed(Duration(milliseconds: 1));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('items exceeding max item count are flushed immediately', () async {
      final buffer = fixture.getSut(
        policy: TelemetryBufferConfig(maxItemCount: 2),
      );

      buffer.add(MockJsonEncodable('item1'));
      expect(fixture.mockTransport.envelopes.length, 0);

      buffer.add(MockJsonEncodable('item2'));

      // Wait briefly for async flush
      await Future.delayed(Duration(milliseconds: 1));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('calling flush directly sends items', () async {
      final buffer = fixture.getSut();

      buffer.add(MockJsonEncodable('item1'));
      buffer.add(MockJsonEncodable('item2'));

      await buffer.flush();

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('timer is only started once and not restarted on subsequent additions',
        () async {
      final flushTimeout = Duration(milliseconds: 100);
      final buffer = fixture.getSut(
        policy: TelemetryBufferConfig(flushTimeout: flushTimeout),
      );

      buffer.add(MockJsonEncodable('item1'));
      expect(fixture.mockTransport.envelopes.length, 0);

      buffer.add(MockJsonEncodable('item2'));
      expect(fixture.mockTransport.envelopes.length, 0);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('flush with empty buffer returns null', () async {
      final buffer = fixture.getSut();

      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.mockTransport.envelopes, isEmpty);
    });

    test('buffer is cleared after flush', () async {
      final buffer = fixture.getSut();

      buffer.add(MockJsonEncodable('item1'));
      await buffer.flush();

      expect(fixture.mockTransport.envelopes.length, 1);

      // Second flush should not send anything
      fixture.mockEnvelopeBuilder.receivedItems = null;
      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, isNull);
    });

    test('multiple envelopes are all sent when builder returns multiple',
        () async {
      fixture.mockEnvelopeBuilder.envelopesToReturn = 3;
      final buffer = fixture.getSut();

      buffer.add(MockJsonEncodable('item1'));
      await buffer.flush();

      expect(fixture.mockTransport.envelopes.length, 3);
    });

    test('encoding failure does not crash and item is skipped', () async {
      final buffer = fixture.getSut();

      buffer.add(ThrowingTelemetryItem());
      buffer.add(MockJsonEncodable('valid'));
      await buffer.flush();

      // Only the valid item should be in the buffer
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(1));
      expect(fixture.mockTransport.envelopes.length, 1);
    });
  });
}

class _Fixture {
  final mockTransport = MockTransport();
  final mockEnvelopeBuilder = _MockEnvelopeBuilder();

  InMemoryTelemetryBuffer<MockJsonEncodable> getSut({
    TelemetryBufferConfig policy = const TelemetryBufferConfig(),
  }) {
    mockEnvelopeBuilder.receivedItems = null;
    return InMemoryTelemetryBuffer<MockJsonEncodable>(
      logger: (level, message, {logger, exception, stackTrace}) {},
      envelopeBuilder: mockEnvelopeBuilder,
      transport: mockTransport,
      policy: policy,
    );
  }
}

class _MockEnvelopeBuilder implements EnvelopeBuilder<MockJsonEncodable> {
  List<BufferedItem<MockJsonEncodable>>? receivedItems;
  int envelopesToReturn = 1;

  @override
  List<SentryEnvelope> build(List<BufferedItem<MockJsonEncodable>> items) {
    receivedItems = items;
    return List.generate(
      envelopesToReturn,
      (_) => SentryEnvelope(
        SentryEnvelopeHeader(null, SdkVersion(name: 'test', version: '1.0.0')),
        [],
      ),
    );
  }
}
