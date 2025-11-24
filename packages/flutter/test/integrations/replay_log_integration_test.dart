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

      // With sessionSampleRate = 0, scope replay ID should not be used
      // (even though it's set, we're not in session mode)
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

      // With sessionSampleRate = null (treated as 0), scope replay ID should not be used
      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'uses replay_id when set on scope and sessionSampleRate > 0 (active session mode)',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.sessionSampleRate = 0.5;
      fixture.options.replay.onErrorSampleRate = 0.5;
      final replayId = SentryId.fromId('test-replay-id');
      fixture.hub.scope.replayId = replayId;

      // Mock native replayId with the same value (same replay, just also set on scope)
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // Should use the replay ID from scope (active session mode)
      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      // Should NOT add buffering flag when replay is active on scope
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'adds replay_id and buffering flag when replay is in buffer mode (scope null, native has ID)',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = 0.5;
      // Scope replay ID is null (default), so we're in buffer mode

      // Mock native replayId to simulate buffering mode (same replay, not on scope yet)
      final replayId = SentryId.fromId('test-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // In buffering mode, use native replay ID and add buffering flag
      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
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
      // Scope replay ID is null (default)

      // Mock native replayId to simulate what would be buffering mode
      final replayId = SentryId.fromId('test-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When onErrorSampleRate is 0, native replayId should be ignored even if it exists
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
      // Scope replay ID is null (default)

      // Mock native replayId to simulate what would be buffering mode
      final replayId = SentryId.fromId('test-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When onErrorSampleRate is null (treated as 0), native replayId should be ignored
      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'adds replay_id when scope is null but native has ID and onErrorSampleRate > 0 (buffer mode)',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.sessionSampleRate = 0.0;
      fixture.options.replay.onErrorSampleRate = 0.5;
      // Scope replay ID is null (default), so we're in buffer mode

      // Mock native replayId to simulate buffering mode (replay exists but not on scope)
      final replayId = SentryId.fromId('test-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      // When scope is null but native has replay ID, use it in buffer mode
      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
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
      final replayId = SentryId.fromId('test-replay-id');
      when(fixture.nativeBinding.replayId).thenReturn(replayId);

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
      attributes: <String, SentryAttribute>{},
    );
  }

  ReplayLogIntegration getSut() {
    return ReplayLogIntegration(nativeBinding);
  }
}
