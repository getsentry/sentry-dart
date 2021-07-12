import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/deduplication_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_transport.dart';

void main() {
  group('$DeduplicationEventProcessor', () {
    var fixture = Fixture();

    test('deduplicates if enabled', () {
      final sut = fixture.getSut(true);
      var ogEvent = createEvent('foo');

      expect(sut.apply(ogEvent), isNotNull);
      expect(sut.apply(ogEvent), isNull);
    });

    test('does not deduplicate if disabled', () {
      final sut = fixture.getSut(false);
      var ogEvent = createEvent('foo');

      expect(sut.apply(ogEvent), isNotNull);
      expect(sut.apply(ogEvent), isNotNull);
    });

    test('does not deduplicate if different events', () {
      final sut = fixture.getSut(false);
      var fooEvent = createEvent('foo');
      var barEvent = createEvent('bar');

      expect(sut.apply(fooEvent), isNotNull);
      expect(sut.apply(barEvent), isNotNull);
    });

    test('exceptions to keep for deduplication', () {
      final sut = fixture.getSut(false, 2);

      var fooEvent = createEvent('foo');
      var barEvent = createEvent('bar');
      var fooBarEvent = createEvent('foo bar');

      expect(sut.apply(fooEvent), isNotNull);
      expect(sut.apply(barEvent), isNotNull);
      expect(sut.apply(fooBarEvent), isNotNull);
      expect(sut.apply(fooEvent), isNotNull);
    });

    test('integration test', () async {
      Future<void> innerThrowingMethod() async {
        try {
          throw Exception('foo bar');
        } catch (e, stackTrace) {
          await Sentry.captureException(e, stackTrace: stackTrace);
          rethrow;
        }
      }

      Future<void> outerThrowingMethod() async {
        try {
          await innerThrowingMethod();
        } catch (e, stackTrace) {
          await Sentry.captureException(e, stackTrace: stackTrace);
        }
      }

      final transport = MockTransport();

      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          options.transport = transport;
          options.enableDeduplication = true;
        },
      );

      // The test doesn't work if `outerTestMethod` is passed as
      // `appRunner` callback
      await outerThrowingMethod();

      expect(transport.envelopes.length, 1);

      await Sentry.close();
    });
  });
}

SentryEvent createEvent(String message) {
  return SentryEvent(throwable: Exception(message));
}

class Fixture {
  DeduplicationEventProcessor getSut(bool enabled,
      [int? maxDeduplicationItems]) {
    final options = SentryOptions(dsn: fakeDsn)
      ..enableDeduplication = enabled
      ..maxDeduplicationItems = maxDeduplicationItems ?? 5;

    return DeduplicationEventProcessor(options);
  }
}
