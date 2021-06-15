import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/deduplication_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('$DeduplicationEventProcessor', () {
    test('deduplicates', () {
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
  });
}

SentryEvent createEvent(var message) {
  return SentryEvent(throwable: Exception(message));
}

class Fixture {
  DeduplicationEventProcessor getSut(bool enable) {
    final options = SentryOptions(dsn: fakeDsn)..enableDeduplication = enable;

    return DeduplicationEventProcessor(options);
  }
}
