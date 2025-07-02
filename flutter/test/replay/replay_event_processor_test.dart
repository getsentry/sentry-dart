// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/replay_event_processor.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late _Fixture fixture;
  setUp(() {
    fixture = _Fixture();
  });

  for (var isHandled in [true, false]) {
    test(
        'sets scope replay ID for ${isHandled ? 'handled' : 'unhandled'} exceptions',
        () async {
      expect(fixture.scope.replayId, isNull);
      await fixture.apply(isHandled: isHandled);
      expect(fixture.scope.replayId, SentryId.fromId('42'));
    });
  }

  test('captures replay for feedback event', () async {
    final feedback = SentryFeedback(message: 'fixture-message');
    final feedbackEvent = SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: feedback),
    );

    expect(fixture.scope.replayId, isNull);

    final processedEvent = await fixture.sut.apply(feedbackEvent, Hint());
    expect(processedEvent, isNotNull);

    await fixture.apply(hasException: false);

    expect(fixture.scope.replayId, isNotNull);
  });

  test('sets scope replay ID for feedback event', () async {
    final feedback = SentryFeedback(message: 'fixture-message');
    final feedbackEvent = SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: feedback),
    );

    final processedEvent = await fixture.sut.apply(feedbackEvent, Hint());
    expect(processedEvent, isNotNull);

    expect(fixture.scope.replayId, SentryId.fromId('42'));
  });

  test('does not capture replay for non-errors', () async {
    await fixture.apply(hasException: false);
    verifyNever(fixture.binding.captureReplay());
    expect(fixture.scope.replayId, isNull);
  });
}

class _Fixture {
  late final ReplayEventProcessor sut;
  final MockHub hub = MockHub();
  final MockSentryNativeBinding binding = MockSentryNativeBinding();
  Scope scope = Scope(defaultTestOptions());

  _Fixture() {
    when(binding.captureReplay())
        .thenAnswer((_) async => SentryId.fromId('42'));
    when(hub.configureScope(any)).thenAnswer((invocation) async {
      final callback = invocation.positionalArguments.first as FutureOr<void>
          Function(Scope);
      await callback(scope);
    });
    sut = ReplayEventProcessor(hub, binding);
  }
  Future<SentryEvent?> apply(
      {bool hasException = true, bool isHandled = false}) {
    final event = SentryEvent(
      eventId: SentryId.newId(),
      exceptions: hasException
          ? [
              SentryException(
                  type: 'type',
                  value: 'value',
                  mechanism: Mechanism(type: 'foo', handled: isHandled))
            ]
          : [],
    );
    return sut.apply(event, Hint());
  }
}
