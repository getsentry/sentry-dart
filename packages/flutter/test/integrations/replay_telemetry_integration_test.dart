// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/replay_telemetry_integration.dart';

import '../mocks.mocks.dart';

const _replayId = SemanticAttributesConstants.sentryReplayId;
const _replayIsBuffering =
    SemanticAttributesConstants.sentryInternalReplayIsBuffering;

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$ReplayTelemetryIntegration', () {
    group('when replay is disabled', () {
      test('does not register', () async {
        fixture.options.replay.sessionSampleRate = 0.0;
        fixture.options.replay.onErrorSampleRate = 0.0;

        await fixture.getSut().call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations,
            isNot(contains('ReplayTelemetry')));
      });
    });

    group('when replay is enabled', () {
      test('registers integration', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations, contains('ReplayTelemetry'));
      });

      test('registers initial trace id with native replay', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);

        verify(fixture.nativeBinding.registerTraceId(
          fixture.scope.propagationContext.traceId,
        )).called(1);
      });

      test('registers generated trace id with native replay', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        final traceId = SentryId.newId();
        final spanId = SpanId.newId();

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnGenerateNewTrace(traceId, spanId));

        verify(fixture.nativeBinding.registerTraceId(traceId)).called(1);
      });

      test('waits for generated trace id registration with native replay',
          () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        final traceId = SentryId.newId();
        final spanId = SpanId.newId();
        final completer = Completer<void>();
        var dispatchCompleted = false;

        when(fixture.nativeBinding.registerTraceId(traceId))
            .thenAnswer((_) => completer.future);

        await fixture.getSut().call(fixture.hub, fixture.options);
        final dispatch = fixture.options.lifecycleRegistry
            .dispatchCallback(OnGenerateNewTrace(traceId, spanId));
        unawaited(Future<void>.value(dispatch).then((_) {
          dispatchCompleted = true;
        }));
        await Future<void>.delayed(Duration.zero);

        expect(dispatchCompleted, false);

        completer.complete();
        await dispatch;

        expect(dispatchCompleted, true);
      });

      test('does not register segment span trace id with native replay',
          () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        final span = fixture.createTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.nativeBinding.registerTraceId(any));
      });

      test('does not register child span trace id with native replay',
          () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        final span = fixture.createChildTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.nativeBinding.registerTraceId(any));
      });

      test('registers segment name with native replay', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        final span = fixture.createTestSpan(name: 'CheckoutScreen');
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verify(fixture.nativeBinding.registerSegmentName('CheckoutScreen'))
            .called(1);
      });

      test('does not register segment name for child spans', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        final span = fixture.createChildTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.nativeBinding.registerSegmentName(any));
      });

      test('does not register empty segment name', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        await fixture.getSut().call(fixture.hub, fixture.options);
        clearInteractions(fixture.nativeBinding);
        final span = fixture.createTestSpan(name: '');
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.nativeBinding.registerSegmentName(any));
      });
    });

    group('in session mode', () {
      setUp(() {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.scope.replayId = SentryId.fromId('test-replay-id');
      });

      test('adds replay_id to logs', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes[_replayId]?.value, 'testreplayid');
      });

      test('adds replay_id to metrics', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final metric = fixture.createTestMetric();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        expect(metric.attributes[_replayId]?.value, 'testreplayid');
      });

      test('adds replay_id to spans', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final span = fixture.createTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        expect(span.attributes[_replayId]?.value, 'testreplayid');
      });

      test('does not add buffering flag', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes.containsKey(_replayIsBuffering), false);
      });
    });

    group('in buffer mode', () {
      setUp(() {
        fixture.options.replay.onErrorSampleRate = 0.5;
        when(fixture.nativeBinding.replayId)
            .thenReturn(SentryId.fromId('test-replay-id'));
      });

      test('adds replay_id to logs', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes[_replayId]?.value, 'testreplayid');
      });

      test('adds replay_id to metrics', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final metric = fixture.createTestMetric();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        expect(metric.attributes[_replayId]?.value, 'testreplayid');
      });

      test('adds replay_id to spans', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final span = fixture.createTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        expect(span.attributes[_replayId]?.value, 'testreplayid');
      });

      test('adds buffering flag', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes[_replayIsBuffering]?.value, true);
      });

      test('adds buffering flag to spans', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final span = fixture.createTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        expect(span.attributes[_replayIsBuffering]?.value, true);
      });
    });

    group('with zero or null sample rates', () {
      for (final rate in [0.0, null]) {
        test('ignores scope replayId when sessionSampleRate is $rate',
            () async {
          fixture.options.replay.sessionSampleRate = rate;
          fixture.options.replay.onErrorSampleRate = 0.5;
          fixture.scope.replayId = SentryId.fromId('test-replay-id');

          await fixture.getSut().call(fixture.hub, fixture.options);

          final log = fixture.createTestLog();
          await fixture.hub.captureLog(log);

          expect(log.attributes.containsKey(_replayId), false);
        });

        test('ignores scope replayId for spans when sessionSampleRate is $rate',
            () async {
          fixture.options.replay.sessionSampleRate = rate;
          fixture.options.replay.onErrorSampleRate = 0.5;
          fixture.scope.replayId = SentryId.fromId('test-replay-id');

          await fixture.getSut().call(fixture.hub, fixture.options);

          final span = fixture.createTestSpan();
          await fixture.options.lifecycleRegistry
              .dispatchCallback(OnProcessSpan(span));

          expect(span.attributes.containsKey(_replayId), false);
        });

        test('ignores native replayId when onErrorSampleRate is $rate',
            () async {
          fixture.options.replay.sessionSampleRate = 0.5;
          fixture.options.replay.onErrorSampleRate = rate;
          when(fixture.nativeBinding.replayId)
              .thenReturn(SentryId.fromId('test-replay-id'));

          await fixture.getSut().call(fixture.hub, fixture.options);

          final log = fixture.createTestLog();
          await fixture.hub.captureLog(log);

          expect(log.attributes.containsKey(_replayId), false);
        });

        test(
            'ignores native replayId for spans when onErrorSampleRate is $rate',
            () async {
          fixture.options.replay.sessionSampleRate = 0.5;
          fixture.options.replay.onErrorSampleRate = rate;
          when(fixture.nativeBinding.replayId)
              .thenReturn(SentryId.fromId('test-replay-id'));

          await fixture.getSut().call(fixture.hub, fixture.options);

          final span = fixture.createTestSpan();
          await fixture.options.lifecycleRegistry
              .dispatchCallback(OnProcessSpan(span));

          expect(span.attributes.containsKey(_replayId), false);
        });
      }
    });

    group('when closed', () {
      test('removes log callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.scope.replayId = SentryId.fromId('test-replay-id');

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes.containsKey(_replayId), false);
      });

      test('removes metric callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.scope.replayId = SentryId.fromId('test-replay-id');

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();

        final metric = fixture.createTestMetric();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        expect(metric.attributes.containsKey(_replayId), false);
      });

      test('removes span callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.scope.replayId = SentryId.fromId('test-replay-id');

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();

        final span = fixture.createTestSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        expect(span.attributes.containsKey(_replayId), false);
      });

      test('removes generate new trace callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();
        clearInteractions(fixture.nativeBinding);

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnGenerateNewTrace(
          SentryId.newId(),
          SpanId.newId(),
        ));

        verifyNever(fixture.nativeBinding.registerTraceId(any));
      });

      test('removes segment name registration on close', () async {
        fixture.options.replay.sessionSampleRate = 0.5;

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();
        clearInteractions(fixture.nativeBinding);

        final span = fixture.createTestSpan(name: 'CheckoutScreen');
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.nativeBinding.registerSegmentName(any));
      });
    });
  });
}

class Fixture {
  final options =
      SentryFlutterOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567');
  final hub = MockHub();
  final nativeBinding = MockSentryNativeBinding();
  late final scope = Scope(options);

  Fixture() {
    options.enableLogs = true;
    options.environment = 'test';
    options.release = 'test-release';

    when(hub.options).thenReturn(options);
    when(hub.scope).thenReturn(scope);
    when(hub.captureLog(any)).thenAnswer((invocation) async {
      final log = invocation.positionalArguments.first as SentryLog;
      await options.lifecycleRegistry.dispatchCallback(OnProcessLog(log));
    });
    when(nativeBinding.replayId).thenReturn(null);
    when(nativeBinding.registerTraceId(any)).thenReturn(null);
    when(nativeBinding.registerSegmentName(any)).thenReturn(null);
  }

  SentryLog createTestLog() => SentryLog(
        timestamp: DateTime.now(),
        traceId: SentryId.newId(),
        level: SentryLogLevel.info,
        body: 'test log message',
        attributes: <String, SentryAttribute>{},
      );

  SentryMetric createTestMetric() => SentryCounterMetric(
        timestamp: DateTime.now(),
        name: 'test-metric',
        value: 1,
        traceId: SentryId.newId(),
        attributes: <String, SentryAttribute>{},
      );

  RecordingSentrySpanV2 createTestSpan({String name = 'test-span'}) =>
      RecordingSentrySpanV2.root(
        name: name,
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: options.clock,
        dscCreator: (span) =>
            SentryTraceContextHeader(span.traceId, 'publicKey'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );

  RecordingSentrySpanV2 createChildTestSpan() => RecordingSentrySpanV2.child(
        parent: createTestSpan(),
        name: 'test-child-span',
        onSpanEnd: (_) async {},
        clock: options.clock,
        dscCreator: (span) =>
            SentryTraceContextHeader(span.traceId, 'publicKey'),
      );

  ReplayTelemetryIntegration getSut() =>
      ReplayTelemetryIntegration(nativeBinding);
}
