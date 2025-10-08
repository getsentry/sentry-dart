// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/replay_log_integration.dart';

import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('ReplayLogIntegration', () {
    test('does not register when replay is disabled', () async {
      final integration = fixture.getSut();
      fixture.options.replay.sessionSampleRate = 0.0;
      fixture.options.replay.onErrorSampleRate = 0.0;

      await integration.call(fixture.hub, fixture.options);

      // Integration should not be registered when replay is disabled
      expect(fixture.options.sdk.integrations.contains('ReplayLog'), false);
    });

    test(
        'adds replay_id attribute when sessionSampleRate > 0 and scope replayId is set',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      // When scope replayId is set via session sample rate, no buffering flag should be added
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'does not add replay_id when sessionSampleRate is 0 even if scope replayId is set',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.0;
      fixture.options.replay.onErrorSampleRate = 0.5; // Needed to enable replay
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'does not add replay_id when sessionSampleRate is null even if scope replayId is set',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = null;
      fixture.options.replay.onErrorSampleRate = 0.5; // Needed to enable replay
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'scope replayId takes precedence over native replayId when sessionSampleRate > 0',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.5;
      fixture.options.replay.onErrorSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('scope-replay-id');

      // Mock native replayId to simulate buffering mode
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // Should use scope replayId, not native replayId
      expect(log.attributes['sentry.replay_id']?.value, 'scopereplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      // Should NOT add buffering flag when scope replayId is used
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'adds replay_id and buffering flag when replay is in buffer mode (native replayId set)',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = 0.5;

      // Mock native replayId to simulate buffering mode (Android)
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // In buffering mode, both replay_id and buffering flag should be present
      expect(log.attributes['sentry.replay_id']?.value, 'nativereplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      expect(
          log.attributes['sentry._internal.replay_is_buffering']?.value, true);
      expect(log.attributes['sentry._internal.replay_is_buffering']?.type,
          'boolean');
    });

    test(
        'does not add anything when onErrorSampleRate is 0 and no scope replayId',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.sessionSampleRate = 0.5; // Needed to enable replay
      fixture.options.replay.onErrorSampleRate = 0.0;

      // Mock native replayId to simulate buffering mode
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When onErrorSampleRate is 0, native replayId should be ignored
      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'does not add anything when onErrorSampleRate is null and no scope replayId',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.sessionSampleRate = 0.5; // Needed to enable replay
      fixture.options.replay.onErrorSampleRate = null;

      // Mock native replayId to simulate buffering mode
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When onErrorSampleRate is null, native replayId should be ignored
      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'does not add native replayId when scope replayId is not set and sessionSampleRate is 0',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.sessionSampleRate = 0.0;
      fixture.options.replay.onErrorSampleRate = 0.5;

      // Mock native replayId to simulate buffering mode
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When scope replayId is not set but onErrorSampleRate > 0, should use native replayId
      expect(log.attributes['sentry.replay_id']?.value, 'nativereplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');
      expect(
          log.attributes['sentry._internal.replay_is_buffering']?.value, true);
      expect(log.attributes['sentry._internal.replay_is_buffering']?.type,
          'boolean');
    });

    test('registers integration name in SDK with sessionSampleRate', () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      // Integration name is registered in SDK
      expect(fixture.options.sdk.integrations.contains('ReplayLog'), true);
    });

    test('registers integration name in SDK with onErrorSampleRate', () async {
      final integration = fixture.getSut();

      fixture.options.replay.onErrorSampleRate = 0.5;

      // Mock native replayId
      final nativeReplayId = SentryId.fromId('native-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(nativeReplayId);

      await integration.call(fixture.hub, fixture.options);

      // Integration name is registered in SDK
      expect(fixture.options.sdk.integrations.contains('ReplayLog'), true);
    });

    test('removes callback on close', () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);
      await integration.close();

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test('integration name is correct', () {
      expect(ReplayLogIntegration.integrationName, 'ReplayLog');
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
      // Trigger the lifecycle callback
      await options.lifecycleRegistry.dispatchCallback(OnBeforeCaptureLog(log));
    });

    // Default: no native replayId
    when(nativeBinding.replayId).thenReturn(null);
  }

  SentryLog createTestLog() {
    return SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test log message',
      attributes: <String, SentryLogAttribute>{},
    );
  }

  ReplayLogIntegration getSut() {
    return ReplayLogIntegration(nativeBinding);
  }
}
