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
    test('adds replay_id attribute when replay is active', () async {
      final integration = fixture.getSut();

      fixture.options.replay.onErrorSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      expect(
          log.attributes['sentry._internal.replay_is_buffering']?.value, false);
      expect(log.attributes['sentry._internal.replay_is_buffering']?.type,
          'boolean');
    });

    test('adds replay buffering flag when replay is enabled but not active',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = 0.5;

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);

      expect(
          log.attributes['sentry._internal.replay_is_buffering']?.value, true);
      expect(log.attributes['sentry._internal.replay_is_buffering']?.type,
          'boolean');
    });

    test('does not add buffering flag when onErrorSampleRate is disabled',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = 0.0;

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test(
        'adds replay_id but not buffering flag when onErrorSampleRate is disabled',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = 0.0;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test('does not add buffering flag when onErrorSampleRate is null',
        () async {
      final integration = fixture.getSut();

      fixture.options.replay.onErrorSampleRate = null;

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes.containsKey('sentry.replay_id'), false);
      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test('adds replay_id but not buffering flag when onErrorSampleRate is null',
        () async {
      final integration = fixture.getSut();
      fixture.options.replay.onErrorSampleRate = null;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      final log = fixture.createTestLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['sentry.replay_id']?.value, 'testreplayid');
      expect(log.attributes['sentry.replay_id']?.type, 'string');

      expect(log.attributes.containsKey('sentry._internal.replay_is_buffering'),
          false);
    });

    test('registers integration name in SDK', () async {
      final integration = fixture.getSut();

      fixture.options.replay.onErrorSampleRate = 0.5;
      fixture.hub.scope.replayId = SentryId.fromId('test-replay-id');

      await integration.call(fixture.hub, fixture.options);

      // Integration name is registered in SDK
      expect(fixture.options.sdk.integrations.contains('ReplayLog'), true);
    });

    test('removes callback on close', () async {
      final integration = fixture.getSut();

      fixture.options.replay.onErrorSampleRate = 0.5;
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
    return ReplayLogIntegration();
  }
}
