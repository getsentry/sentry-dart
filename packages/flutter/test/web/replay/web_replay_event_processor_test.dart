import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_event_processor.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';

void main() {
  group('$WebReplayEventProcessor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds replay ID to event tags', () async {
      final sut = fixture.getSut(replayId: fixture.replayId);
      final event = SentryEvent();

      final processedEvent = await sut.apply(event, Hint());

      expect(processedEvent?.tags?['replayId'], fixture.replayId);
    });

    test('adds replay ID to trace context', () async {
      final sut = fixture.getSut(replayId: fixture.replayId);
      final event = SentryEvent()
        ..contexts.trace = SentryTraceContext(operation: 'default');

      final processedEvent = await sut.apply(event, Hint());

      expect(
        processedEvent?.contexts.trace?.replayId.toString(),
        fixture.replayId,
      );
    });

    test('does not add the ID of an unsampled replay', () async {
      final sut = fixture.getSut(replayId: fixture.replayId, sampled: false);
      final event = SentryEvent();

      final processedEvent = await sut.apply(event, Hint());

      expect(processedEvent?.tags, isNull);
    });

    test('does not change event when replay ID is unavailable', () async {
      final sut = fixture.getSut();
      final event = SentryEvent();

      final processedEvent = await sut.apply(event, Hint());

      expect(processedEvent?.tags, isNull);
    });
  });
}

class Fixture {
  final replayId = '1988bb1b6f0d4c509e232f0cb9aaeaea';

  WebReplayEventProcessor getSut({String? replayId, bool sampled = true}) {
    return WebReplayEventProcessor(
      FakeSentryJsBinding(replayId: replayId, sampled: sampled),
    );
  }
}

class FakeSentryJsBinding implements SentryJsBinding {
  FakeSentryJsBinding({this.replayId, this.sampled = true});

  final String? replayId;
  final bool sampled;

  // Like the JS SDK: an unsampled session's ID only without onlyIfSampled.
  @override
  String? getReplayId({bool onlyIfSampled = false}) =>
      onlyIfSampled && !sampled ? null : replayId;

  @override
  Object? createManualReplayCanvasIntegration() => null;

  @override
  void startReplay() {}

  @override
  void startReplayBuffering() {}

  @override
  Future<void> stopReplay() async {}

  @override
  Future<void> flushReplay() async {}

  @override
  void init(Map<String, dynamic> options) {}

  @override
  void close() {}

  @override
  void captureEnvelope(
    List<Object> envelope,
    List<Map<String, dynamic>> events,
  ) {}

  @override
  void setUser(Map<String, dynamic>? user) {}

  @override
  void addBreadcrumb(Map<String, dynamic> breadcrumb) {}

  @override
  void addReplayBreadcrumb(Map<String, dynamic> breadcrumb) {}

  @override
  void clearBreadcrumbs() {}

  @override
  void setContext(String key, Object? value) {}

  @override
  void removeContext(String key) {}

  @override
  void setExtra(String key, Object? value) {}

  @override
  void removeExtra(String key) {}

  @override
  void setTag(String key, String value) {}

  @override
  void removeTag(String key) {}

  @override
  void startSession() {}

  @override
  Map<dynamic, dynamic>? getSession() => null;

  @override
  void updateSession({int? errors, String? status}) {}

  @override
  void captureSession() {}

  @override
  Map<String, String>? getFilenameToDebugIdMap() => null;

  @override
  dynamic getJsOptions() => null;
}
