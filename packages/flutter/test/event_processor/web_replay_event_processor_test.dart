import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/web_replay_event_processor.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';

void main() {
  group('WebReplayEventProcessor', () {
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

      expect(processedEvent?.contexts.trace?.replayId.toString(),
          fixture.replayId);
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

  WebReplayEventProcessor getSut({String? replayId}) {
    return WebReplayEventProcessor(FakeSentryJsBinding(replayId: replayId));
  }
}

class FakeSentryJsBinding implements SentryJsBinding {
  FakeSentryJsBinding({this.replayId});

  final String? replayId;

  @override
  String? getReplayId({bool onlyIfSampled = false}) => replayId;

  @override
  void init(Map<String, dynamic> options) {}

  @override
  void close() {}

  @override
  void captureEnvelope(List<Object> envelope) {}

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
