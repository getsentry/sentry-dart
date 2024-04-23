import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/event_processor/platform_exception_event_processor.dart';

void main() {
  group(PlatformExceptionEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('applies code and message to mechanism', () {
      final platformException = PlatformException(
        code: 'fixture-code',
        message: 'fixture-message',
      );
      final mechanism = Mechanism(type: 'fixture-type');
      final sentryException = SentryException(
        type: 'fixture-type',
        value: 'fixture-value',
        throwable: platformException,
        mechanism: mechanism,
      );
      var event = SentryEvent(exceptions: [sentryException]);

      final sut = fixture.getSut();
      event = (sut.apply(event, Hint()))!;

      expect(event.exceptions?.first.mechanism?.data["code"], "fixture-code");
      expect(event.exceptions?.first.mechanism?.data["message"],
          "fixture-message");
    });

    test('creates fallback mechanism', () {
      final platformException = PlatformException(
        code: 'fixture-code',
        message: 'fixture-message',
      );
      final sentryException = SentryException(
        type: 'fixture-type',
        value: 'fixture-value',
        throwable: platformException,
      );
      var event = SentryEvent(exceptions: [sentryException]);

      final sut = fixture.getSut();
      event = (sut.apply(event, Hint()))!;

      expect(event.exceptions?.first.mechanism?.type, "platformException");
    });
  });
}

class Fixture {
  PlatformExceptionEventProcessor getSut() {
    return PlatformExceptionEventProcessor();
  }
}
