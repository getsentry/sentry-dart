import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/deduplication_event_processor.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_hub.dart';
import '../mocks/mock_transport.dart';
import '../test_utils.dart';

void main() {
  group('$DeduplicationEventProcessor', () {
    final fixture = Fixture();

    test('deduplicates if enabled', () {
      final sut = fixture.getSut(true);
      var ogEvent = _createEvent('foo');

      expect(sut.apply(ogEvent, Hint()), isNotNull);
      expect(sut.apply(ogEvent, Hint()), isNull);
    });

    test('does not deduplicate if disabled', () {
      final sut = fixture.getSut(false);
      var ogEvent = _createEvent('foo');

      expect(sut.apply(ogEvent, Hint()), isNotNull);
      expect(sut.apply(ogEvent, Hint()), isNotNull);
    });

    test('does not deduplicate if different events', () {
      final sut = fixture.getSut(true);
      var fooEvent = _createEvent('foo');
      var barEvent = _createEvent('bar');

      expect(sut.apply(fooEvent, Hint()), isNotNull);
      expect(sut.apply(barEvent, Hint()), isNotNull);
    });

    test('does not deduplicate transaction', () {
      final sut = fixture.getSut(true);
      final transaction = _createTransaction(fixture.hub);

      expect(sut.apply(transaction, Hint()), isNotNull);
      expect(sut.apply(transaction, Hint()), isNotNull);
    });

    test('exceptions to keep for deduplication', () {
      final sut = fixture.getSut(true, 2);

      var fooEvent = _createEvent('foo');
      var barEvent = _createEvent('bar');
      var fooBarEvent = _createEvent('foo bar');

      expect(sut.apply(fooEvent, Hint()), isNotNull);
      expect(sut.apply(barEvent, Hint()), isNotNull);
      expect(sut.apply(fooBarEvent, Hint()), isNotNull);
      expect(sut.apply(fooEvent, Hint()), isNotNull);
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
        options: defaultTestOptions(),
      );

      // The test doesn't work if `outerTestMethod` is passed as
      // `appRunner` callback
      await outerThrowingMethod();

      expect(transport.envelopes.length, 1);

      await Sentry.close();
    });
  });
}

SentryEvent _createEvent(String message) {
  return SentryEvent(throwable: Exception(message));
}

SentryTransaction _createTransaction(Hub hub) {
  final context = SentryTransactionContext('name', 'op');

  final tracer = SentryTracer(context, hub);
  return SentryTransaction(tracer);
}

class Fixture {
  final hub = MockHub();

  DeduplicationEventProcessor getSut(bool enabled,
      [int? maxDeduplicationItems]) {
    final options = defaultTestOptions()
      ..enableDeduplication = enabled
      ..maxDeduplicationItems = maxDeduplicationItems ?? 5;

    return DeduplicationEventProcessor(options);
  }
}
