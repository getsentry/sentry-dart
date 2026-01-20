// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
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
    });

    group('in session mode', () {
      setUp(() {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');
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

      test('adds buffering flag', () async {
        await fixture.getSut().call(fixture.hub, fixture.options);

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes[_replayIsBuffering]?.value, true);
      });
    });

    group('with zero or null sample rates', () {
      for (final rate in [0.0, null]) {
        test('ignores scope replayId when sessionSampleRate is $rate',
            () async {
          fixture.options.replay.sessionSampleRate = rate;
          fixture.options.replay.onErrorSampleRate = 0.5;
          fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

          await fixture.getSut().call(fixture.hub, fixture.options);

          final log = fixture.createTestLog();
          await fixture.hub.captureLog(log);

          expect(log.attributes.containsKey(_replayId), false);
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
      }
    });

    group('when closed', () {
      test('removes log callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();

        final log = fixture.createTestLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes.containsKey(_replayId), false);
      });

      test('removes metric callback', () async {
        fixture.options.replay.sessionSampleRate = 0.5;
        fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

        final sut = fixture.getSut();
        await sut.call(fixture.hub, fixture.options);
        await sut.close();

        final metric = fixture.createTestMetric();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        expect(metric.attributes.containsKey(_replayId), false);
      });
    });
  });
}

class Fixture {
  final options =
      SentryFlutterOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567');
  final hub = MockHub();
  final nativeBinding = MockSentryNativeBinding();

  Fixture() {
    options.enableLogs = true;
    options.environment = 'test';
    options.release = 'test-release';

    final scope = Scope(options);
    when(hub.options).thenReturn(options);
    when(hub.scope).thenReturn(scope);
    when(hub.captureLog(any)).thenAnswer((invocation) async {
      final log = invocation.positionalArguments.first as SentryLog;
      await options.lifecycleRegistry.dispatchCallback(OnProcessLog(log));
    });
    when(nativeBinding.replayId).thenReturn(null);
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

  ReplayTelemetryIntegration getSut() =>
      ReplayTelemetryIntegration(nativeBinding);
}
