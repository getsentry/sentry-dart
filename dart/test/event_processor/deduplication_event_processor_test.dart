import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/deduplication_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_transport.dart';

void main() {
  group('$DeduplicationEventProcessor', () {
    test('deduplicates if enabled', () {
      final sut = Fixture().getSut(true);
      var ogEvent = createEvent('foo');

      expect(sut.apply(ogEvent), isNotNull);
      expect(sut.apply(ogEvent), isNull);
    });

    test('does not deduplicate if disabled', () {
      final sut = Fixture().getSut(false);
      var ogEvent = createEvent('foo');

      expect(sut.apply(ogEvent), isNotNull);
      expect(sut.apply(ogEvent), isNotNull);
    });

    test('does not deduplicate if different events', () {
      final sut = Fixture().getSut(false);
      var fooEvent = createEvent('foo');
      var barEvent = createEvent('bar');

      expect(sut.apply(fooEvent), isNotNull);
      expect(sut.apply(barEvent), isNotNull);
    });

    test('exceptions to keep for deduplication', () {
      final sut = Fixture().getSut(false, 2);

      var fooEvent = createEvent('foo');
      var barEvent = createEvent('bar');
      var fooBarEvent = createEvent('foo bar');

      expect(sut.apply(fooEvent), isNotNull);
      expect(sut.apply(barEvent), isNotNull);
      expect(sut.apply(fooBarEvent), isNotNull);
      expect(sut.apply(fooEvent), isNotNull);
    });

    test('$DeduplicationEventProcessor is added on init', () async {
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          final count = options.eventProcessors
              .whereType<DeduplicationEventProcessor>()
              .length;
          expect(count, 1);
        },
      );

      await Sentry.close();
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

      // doesn't work with outerTestMethod as appRunner Callback
      await outerThrowingMethod();

      expect(transport.envelopes.length, 1);

      await Sentry.close();
    });
  });
}

SentryEvent createEvent(var message) {
  return SentryEvent(throwable: Exception(message));
}

class Fixture {
  DeduplicationEventProcessor getSut(bool enabled,
      [int? exceptionsToKeepForDeduplication]) {
    final options = SentryOptions(dsn: fakeDsn)
      ..enableDeduplication = enabled
      ..exceptionsToKeepForDeduplication =
          exceptionsToKeepForDeduplication ?? 5;

    return DeduplicationEventProcessor(options);
  }
}
