import 'package:test/test.dart';
import 'package:sentry/src/sentry_log_batcher.dart';
import 'package:sentry/src/sentry_options.dart';
import 'package:sentry/src/protocol/sentry_log.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';

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

  test('max logs are flushed immediately', () async {
    final batcher = fixture.getSut(maxBufferSize: 10);

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    for (var i = 0; i < 10; i++) {
      await batcher.addLog(log);
    }

    expect(fixture.mockTransport.envelopes.length, 1);
    final envelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(envelopePayloadJson, isNotNull);
    expect(envelopePayloadJson['items'].length, 10);
  });

  test('more than max logs are flushed eventuelly', () async {
    final flushTimeout = Duration(milliseconds: 100);
    final batcher = fixture.getSut(maxBufferSize: 10, flushTimeout: flushTimeout);

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    for (var i = 0; i < 15; i++) {
      batcher.addLog(log);
    }

    await Future.delayed(flushTimeout);

    expect(fixture.mockTransport.envelopes.length, 2);

    final firstEnvelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(firstEnvelopePayloadJson, isNotNull);
    expect(firstEnvelopePayloadJson['items'].length, 10);

    final secondEnvelopePayloadJson = (fixture.mockTransport).logs.last;

    expect(secondEnvelopePayloadJson, isNotNull);
    expect(secondEnvelopePayloadJson['items'].length, 5);
  });
  

  test('calling flush directly flushes logs', () async {
    final batcher = fixture.getSut();

    final log = SentryLog(
      timestamp: DateTime.now(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );

    await batcher.addLog(log);
    await batcher.addLog(log);

    await batcher.flush();

    expect(fixture.mockTransport.envelopes.length, 1);
    final envelopePayloadJson = (fixture.mockTransport).logs.first;

    expect(envelopePayloadJson, isNotNull);
    expect(envelopePayloadJson['items'].length, 2);
  });
}

class Fixture {
  final options = SentryOptions();
  final mockTransport = MockTransport();

  Fixture() {
    options.transport = mockTransport;
  }

  SentryLogBatcher getSut({Duration? flushTimeout, int? maxBufferSize}) {
    return SentryLogBatcher(
      options,
      flushTimeout: flushTimeout,
      maxBufferSize: maxBufferSize,
    );
  }
}
