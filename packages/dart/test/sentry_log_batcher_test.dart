import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_log_batcher.dart';
import 'package:test/test.dart';

import 'mocks/mock_transport.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('added logs are flushed after timeout', () async {
    final flushTimeout = Duration(milliseconds: 1);

    final batcher = fixture.getSut(flushTimeout: flushTimeout);

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );
    final log2 = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test2',
      attributes: {},
    );

    batcher.addLog(log);
    batcher.addLog(log2);

    expect(fixture.mockTransport.envelopes.length, 0);

    await Future.delayed(flushTimeout);

    expect(fixture.mockTransport.envelopes.length, 1);

    final envelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(envelopePayloadJson, isNotNull);
    expect(envelopePayloadJson['items'].length, 2);
    expect(envelopePayloadJson['items'].first['body'], log.body);
    expect(envelopePayloadJson['items'].last['body'], log2.body);
  });

  test('logs exeeding max size are flushed without timeout', () async {
    // Use a buffer size that can hold multiple logs before triggering flush
    // Each log is ~153 bytes, so 300 bytes can hold 1 log, triggering flush on 2nd
    final batcher = fixture.getSut(maxBufferSizeBytes: 300);

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    // Add first log - should fit in buffer
    batcher.addLog(log);
    expect(fixture.mockTransport.envelopes.length, 0);

    // Add second log - should exceed buffer and trigger flush
    batcher.addLog(log);

    // Just wait a little bit, as we call capture without awaiting internally.
    await Future.delayed(Duration(milliseconds: 1));

    expect(fixture.mockTransport.envelopes.length, 1);
    final envelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(envelopePayloadJson, isNotNull);
    expect(envelopePayloadJson['items'].length, 2);
  });

  test('calling flush directly flushes logs', () async {
    final batcher = fixture.getSut();

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    batcher.addLog(log);
    batcher.addLog(log);
    batcher.flush();

    // Just wait a little bit, as we call capture without awaiting internally.
    await Future.delayed(Duration(milliseconds: 1));

    expect(fixture.mockTransport.envelopes.length, 1);
    final envelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(envelopePayloadJson, isNotNull);
    expect(envelopePayloadJson['items'].length, 2);
  });

  test('timeout is only started once and not restarted on subsequent additions',
      () async {
    final flushTimeout = Duration(milliseconds: 100);
    final batcher = fixture.getSut(flushTimeout: flushTimeout);

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    // Add first log - should start timer
    batcher.addLog(log);
    expect(fixture.mockTransport.envelopes.length, 0);

    // Add second log immediately - should NOT restart timer
    batcher.addLog(log);
    expect(fixture.mockTransport.envelopes.length, 0);

    // Wait for timeout to fire
    await Future.delayed(flushTimeout + Duration(milliseconds: 10));

    // Should have sent both logs after timeout
    expect(fixture.mockTransport.envelopes.length, 1);
    final envelopePayloadJson = (fixture.mockTransport).logs.first;
    expect(envelopePayloadJson['items'].length, 2);
  });
}

class Fixture {
  final options = SentryOptions();
  final mockTransport = MockTransport();

  Fixture() {
    options.transport = mockTransport;
  }

  SentryLogBatcher getSut({Duration? flushTimeout, int? maxBufferSizeBytes}) {
    return SentryLogBatcher(
      options,
      flushTimeout: flushTimeout,
      maxBufferSizeBytes: maxBufferSizeBytes,
    );
  }
}
