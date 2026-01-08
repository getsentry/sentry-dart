import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'test_utils.dart';

void main() {
  group('$SentryTraceContextHeader', () {
    final traceId = SentryId.newId();

    final context = SentryTraceContextHeader(
      traceId,
      '123',
      release: 'release',
      environment: 'environment',
      userId: 'user_id',
      transaction: 'transaction',
      sampleRate: '1.0',
      sampled: 'false',
      replayId: SentryId.fromId('456'),
      unknown: testUnknown,
    );

    final mapJson = <String, dynamic>{
      'trace_id': '$traceId',
      'public_key': '123',
      'release': 'release',
      'environment': 'environment',
      'user_id': 'user_id',
      'transaction': 'transaction',
      'sample_rate': '1.0',
      'sampled': 'false',
      'replay_id': '456',
    };
    mapJson.addAll(testUnknown);

    test('fromJson', () {
      expect(context.traceId.toString(), traceId.toString());
      expect(context.publicKey, '123');
      expect(context.release, 'release');
      expect(context.environment, 'environment');
      expect(context.userId, 'user_id');
      expect(context.transaction, 'transaction');
      expect(context.sampleRate, '1.0');
      expect(context.sampled, 'false');
      expect(context.replayId, SentryId.fromId('456'));
    });

    test('toJson', () {
      final json = context.toJson();

      expect(MapEquality().equals(json, mapJson), isTrue);
    });

    test('to baggage', () {
      final baggage = context.toBaggage();

      expect(
        baggage.toHeaderString(),
        'sentry-trace_id=${traceId.toString()},'
        'sentry-public_key=123,'
        'sentry-release=release,'
        'sentry-environment=environment,'
        'sentry-user_id=user_id,'
        'sentry-transaction=transaction,'
        'sentry-sample_rate=1.0,'
        'sentry-sampled=false,'
        'sentry-replay_id=456',
      );
    });

    group('when creating from RecordingSentrySpanV2', () {
      late _Fixture fixture;

      setUp(() {
        fixture = _Fixture();
      });

      test('uses traceId from span', () {
        final spanTraceId = SentryId.newId();
        final span = fixture.createSpan(traceId: spanTraceId);

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.traceId, equals(spanTraceId));
      });

      test('uses publicKey from hub options', () {
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.publicKey, equals('public'));
      });

      test('uses release from hub options', () {
        fixture.options.release = 'test-release@1.0.0';
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.release, equals('test-release@1.0.0'));
      });

      test('uses environment from hub options', () {
        fixture.options.environment = 'test-environment';
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.environment, equals('test-environment'));
      });

      test('uses segment span name as transaction', () {
        final span = fixture.createSpan(name: 'my-transaction-name');

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.transaction, equals('my-transaction-name'));
      });

      test('uses sampleRate from span sampling decision', () {
        // Set options tracesSampleRate to a DIFFERENT value than the span's
        // sampling decision to verify the DSC uses the span's rate
        fixture.options.tracesSampleRate = 0.1;
        final span = fixture.createSpan(
          samplingDecision: SentryTracesSamplingDecision(
            true,
            sampleRate: 0.75,
          ),
        );

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        // Should use span's sampling decision rate (0.75), not options rate (0.1)
        expect(dsc.sampleRate, equals('0.75'));
      });

      test('uses sampleRand from span sampling decision', () {
        fixture.hub.scope.propagationContext.sampleRand = 0.123456;
        final span = fixture.createSpan(
          samplingDecision: SentryTracesSamplingDecision(
            true,
            sampleRand: 0.123456,
          ),
        );

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.sampleRand, equals('0.123456'));
      });

      test('uses sampled from propagation context', () {
        fixture.hub.scope.propagationContext.applySamplingDecision(true);
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.sampled, equals('true'));
      });

      test('uses replayId from scope', () {
        final replayId = SentryId.newId();
        fixture.hub.scope.replayId = replayId;
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.replayId, equals(replayId));
      });

      test('with null replayId returns null', () {
        fixture.hub.scope.replayId = null;
        final span = fixture.createSpan();

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(span, fixture.hub);

        expect(dsc.replayId, isNull);
      });

      test('with child span uses segment span name as transaction', () {
        final rootSpan = fixture.createSpan(name: 'root-transaction');
        final childSpan =
            fixture.createChildSpan(parent: rootSpan, name: 'child-operation');

        final dsc =
            SentryTraceContextHeader.fromRecordingSpan(childSpan, fixture.hub);

        // Should use the root/segment span name, not the child span name
        expect(dsc.transaction, equals('root-transaction'));
      });
    });
  });
}

class _Fixture {
  final options = defaultTestOptions();
  late final Hub hub;

  _Fixture() {
    hub = Hub(options);
  }

  RecordingSentrySpanV2 createSpan({
    String name = 'test-span',
    SentryId? traceId,
    SentryTracesSamplingDecision? samplingDecision,
  }) {
    return RecordingSentrySpanV2.root(
      name: name,
      traceId: traceId ?? SentryId.newId(),
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (span) =>
          SentryTraceContextHeader.fromRecordingSpan(span, hub),
      samplingDecision: samplingDecision ?? SentryTracesSamplingDecision(true),
    );
  }

  RecordingSentrySpanV2 createChildSpan({
    required RecordingSentrySpanV2 parent,
    String name = 'child-span',
  }) {
    return RecordingSentrySpanV2.child(
      parent: parent,
      name: name,
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (span) =>
          SentryTraceContextHeader.fromRecordingSpan(span, hub),
    );
  }
}
