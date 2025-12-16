import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/telemetry_processing/envelope_builder.dart';
import 'package:sentry/src/telemetry_processing/in_memory_telemetry_buffer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_item.dart';
import 'package:test/test.dart';

import '../mocks/mock_transport.dart';

void main() {
  group('InMemoryTelemetryBuffer', () {
    late _Fixture fixture;

    setUp(() {
      fixture = _Fixture();
    });

    test('items are flushed after timeout', () async {
      final flushTimeout = Duration(milliseconds: 1);
      final buffer = fixture.getSut(flushTimeout: flushTimeout);

      buffer.add(_MockTelemetryItem('item1'));
      buffer.add(_MockTelemetryItem('item2'));

      expect(fixture.mockTransport.envelopes.length, 0);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('items exceeding max size are flushed immediately', () async {
      // Each item encodes to ~14 bytes ({"id":"item1"}), so 20 bytes triggers flush on 2nd item
      final buffer = fixture.getSut(maxBufferSizeBytes: 20);

      buffer.add(_MockTelemetryItem('item1'));
      expect(fixture.mockTransport.envelopes.length, 0);

      buffer.add(_MockTelemetryItem('item2'));

      // Wait briefly for async flush
      await Future.delayed(Duration(milliseconds: 1));

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('calling flush directly sends items', () async {
      final buffer = fixture.getSut();

      buffer.add(_MockTelemetryItem('item1'));
      buffer.add(_MockTelemetryItem('item2'));

      await buffer.flush();

      expect(fixture.mockTransport.envelopes.length, 1);
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(2));
    });

    test('timer is only started once and not restarted on subsequent additions',
        () async {
      final flushTimeout = Duration(milliseconds: 100);
      final buffer = fixture.getSut(flushTimeout: flushTimeout);

      buffer.add(_MockTelemetryItem('item1'));
      expect(fixture.mockTransport.envelopes.length, 0);

      buffer.add(_MockTelemetryItem('item2'));
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

      buffer.add(_MockTelemetryItem('item1'));
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

      buffer.add(_MockTelemetryItem('item1'));
      await buffer.flush();

      expect(fixture.mockTransport.envelopes.length, 3);
    });

    test('encoding failure does not crash and item is skipped', () async {
      final buffer = fixture.getSut();

      buffer.add(_ThrowingTelemetryItem());
      buffer.add(_MockTelemetryItem('valid'));
      await buffer.flush();

      // Only the valid item should be in the buffer
      expect(fixture.mockEnvelopeBuilder.receivedItems, hasLength(1));
      expect(fixture.mockTransport.envelopes.length, 1);
    });

    test('transport failure does not crash', () async {
      final buffer = fixture.getSut(throwOnSend: true);

      buffer.add(_MockTelemetryItem('item1'));

      // Should not throw
      await buffer.flush();

      // Transport was called but failed
      expect(fixture.throwingTransport.sendCalled, isTrue);
    });
  });
}

class _Fixture {
  final mockTransport = MockTransport();
  final throwingTransport = _ThrowingTransport();
  final mockEnvelopeBuilder = _MockEnvelopeBuilder();

  InMemoryTelemetryBuffer<_MockTelemetryItem> getSut({
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
    bool throwOnSend = false,
  }) {
    mockEnvelopeBuilder.receivedItems = null;
    return InMemoryTelemetryBuffer<_MockTelemetryItem>(
      logger: (level, message, {logger, exception, stackTrace}) {},
      envelopeBuilder: mockEnvelopeBuilder,
      transport: throwOnSend ? throwingTransport : mockTransport,
      flushTimeout: flushTimeout,
      maxBufferSizeBytes: maxBufferSizeBytes,
    );
  }
}

class _MockTelemetryItem extends TelemetryItem {
  final String id;

  _MockTelemetryItem(this.id);

  @override
  TelemetryType get type => TelemetryType.unknown;

  @override
  Map<String, dynamic> toJson() => {'id': id};
}

class _ThrowingTelemetryItem extends _MockTelemetryItem {
  _ThrowingTelemetryItem() : super('throwing');

  @override
  Map<String, dynamic> toJson() => throw Exception('Encoding failed');
}

class _MockEnvelopeBuilder implements EnvelopeBuilder<_MockTelemetryItem> {
  List<EncodedTelemetryItem<_MockTelemetryItem>>? receivedItems;
  int envelopesToReturn = 1;

  @override
  List<SentryEnvelope> build(
      List<EncodedTelemetryItem<_MockTelemetryItem>> items) {
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

class _ThrowingTransport implements Transport {
  bool sendCalled = false;

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    sendCalled = true;
    throw Exception('Transport failed');
  }
}
