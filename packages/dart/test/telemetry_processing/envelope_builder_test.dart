import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/spans_v2/sentry_span_context_v2.dart';
import 'package:sentry/src/spans_v2/sentry_span_v2.dart';
import 'package:sentry/src/telemetry_processing/envelope_builder.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';

void main() {
  group('LogEnvelopeBuilder', () {
    late LogEnvelopeBuilderFixture fixture;

    setUp(() {
      fixture = LogEnvelopeBuilderFixture();
    });

    test('returns empty list when items is empty', () {
      final sut = fixture.getSut();

      final result = sut.build([]);

      expect(result, isEmpty);
    });

    test('builds single envelope from items', () {
      final sut = fixture.getSut();
      final items = [
        fixture.createBufferedLog('log 1'),
        fixture.createBufferedLog('log 2'),
        fixture.createBufferedLog('log 3'),
      ];

      final result = sut.build(items);

      expect(result.length, 1);
    });

    test('envelope has correct SDK version', () {
      final sut = fixture.getSut();
      final items = [fixture.createBufferedLog('test log')];

      final result = sut.build(items);

      expect(result.first.header.sdkVersion, fixture.sdkVersion);
    });

    test('envelope item contains correct item count', () {
      final sut = fixture.getSut();
      final items = [
        fixture.createBufferedLog('log 1'),
        fixture.createBufferedLog('log 2'),
        fixture.createBufferedLog('log 3'),
      ];

      final result = sut.build(items);

      expect(result.first.items.first.header.itemCount, 3);
    });
  });

  group('SpanEnvelopeBuilder', () {
    late SpanEnvelopeBuilderFixture fixture;

    setUp(() {
      fixture = SpanEnvelopeBuilderFixture();
    });

    test('returns empty list when items is empty', () {
      final sut = fixture.getSut();

      final result = sut.build([]);

      expect(result, isEmpty);
    });

    test('builds single envelope when all spans share same segment', () {
      final sut = fixture.getSut();
      final parentSpan = fixture.createSpan('parent');
      final childSpan = fixture.createChildSpan(parentSpan, 'child');

      final items = [
        fixture.createBufferedSpan(parentSpan),
        fixture.createBufferedSpan(childSpan),
      ];

      final result = sut.build(items);

      expect(result.length, 1);
    });

    test('builds multiple envelopes when spans have different segments', () {
      final sut = fixture.getSut();
      final span1 = fixture.createSpan('span-1');
      final span2 = fixture.createSpan('span-2');

      final items = [
        fixture.createBufferedSpan(span1),
        fixture.createBufferedSpan(span2),
      ];

      final result = sut.build(items);

      expect(result.length, 2);
    });

    test('envelope has correct SDK version', () {
      final sut = fixture.getSut();
      final span = fixture.createSpan('test-span');
      final items = [fixture.createBufferedSpan(span)];

      final result = sut.build(items);

      expect(result.first.header.sdkVersion, fixture.sdkVersion);
    });

    test('envelope has correct DSN', () {
      final sut = fixture.getSut();
      final span = fixture.createSpan('test-span');
      final items = [fixture.createBufferedSpan(span)];

      final result = sut.build(items);

      expect(result.first.header.dsn, fixture.dsn);
    });

    test('envelope has trace context from factory', () {
      final sut = fixture.getSut();
      final span = fixture.createSpan('test-span');
      final items = [fixture.createBufferedSpan(span)];

      final result = sut.build(items);

      expect(result.first.header.traceContext, same(fixture.traceContext));
    });

    test('trace context factory receives first span of each segment', () {
      final capturedSpans = <RecordingSentrySpanV2>[];
      final sut = fixture.getSut(
        traceContextHeaderFactory: (span) {
          capturedSpans.add(span);
          return fixture.traceContext;
        },
      );

      final span1 = fixture.createSpan('span-1');
      final span2 = fixture.createSpan('span-2');
      final items = [
        fixture.createBufferedSpan(span1),
        fixture.createBufferedSpan(span2),
      ];

      sut.build(items);

      expect(capturedSpans.length, 2);
      expect(capturedSpans, contains(span1));
      expect(capturedSpans, contains(span2));
    });

    test('envelope item contains correct item count per segment', () {
      final sut = fixture.getSut();
      final parentSpan = fixture.createSpan('parent');
      final childSpan1 = fixture.createChildSpan(parentSpan, 'child-1');
      final childSpan2 = fixture.createChildSpan(parentSpan, 'child-2');

      final items = [
        fixture.createBufferedSpan(parentSpan),
        fixture.createBufferedSpan(childSpan1),
        fixture.createBufferedSpan(childSpan2),
      ];

      final result = sut.build(items);

      expect(result.length, 1);
      expect(result.first.items.first.header.itemCount, 3);
    });
  });
}

class LogEnvelopeBuilderFixture {
  final sdkVersion = SdkVersion(name: 'test.sdk', version: '1.0.0');

  LogEnvelopeBuilder getSut() {
    return LogEnvelopeBuilder(sdkVersion);
  }

  BufferedItem<SentryLog> createBufferedLog(String body) {
    final log = SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
    final encoded = utf8.encode(jsonEncode(log.toJson()));
    return BufferedItem(log, encoded);
  }
}

class SpanEnvelopeBuilderFixture {
  final sdkVersion = SdkVersion(name: 'test.sdk', version: '1.0.0');
  final dsn = 'https://abc@def.ingest.sentry.io/1234567';
  final traceContext = SentryTraceContextHeader(
    SentryId.newId(),
    'abc',
  );
  final hub = MockHub();

  SpanEnvelopeBuilder getSut({
    TraceContextHeaderFactory? traceContextHeaderFactory,
  }) {
    return SpanEnvelopeBuilder(
      traceContextHeaderFactory:
          traceContextHeaderFactory ?? (_) => traceContext,
      sdkVersion: sdkVersion,
      dsn: dsn,
    );
  }

  SentrySpanContextV2 createContext() {
    return SentrySpanContextV2(
      log: hub.options.log,
      clock: hub.options.clock,
      traceId: SentryId.newId(),
      onSpanEnded: (_) {},
      createDsc: (_) => traceContext,
    );
  }

  RecordingSentrySpanV2 createSpan(String name) {
    return RecordingSentrySpanV2(name: name, context: createContext());
  }

  RecordingSentrySpanV2 createChildSpan(
      RecordingSentrySpanV2 parent, String name) {
    return RecordingSentrySpanV2(
        name: name, parentSpan: parent, context: createContext());
  }

  BufferedItem<RecordingSentrySpanV2> createBufferedSpan(
      RecordingSentrySpanV2 span) {
    final encoded = utf8.encode(jsonEncode(span.toJson()));
    return BufferedItem(span, encoded);
  }
}
