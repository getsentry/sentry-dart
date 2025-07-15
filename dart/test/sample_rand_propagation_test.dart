import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('sampleRand', () {
    test('is reused for transactions within the same trace', () {
      final options = defaultTestOptions()..tracesSampleRate = 1.0;
      final hub = Hub(options);

      final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
      final rand1 = tx1.samplingDecision?.sampleRand;

      // Sanity check
      expect(rand1, isNotNull);

      final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
      final rand2 = tx2.samplingDecision?.sampleRand;

      expect(rand2, equals(rand1));
    });

    test('is generated within a transaction in a new trace', () {
      final options = defaultTestOptions()..tracesSampleRate = 1.0;
      final hub = Hub(options);

      final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
      final rand1 = tx1.samplingDecision?.sampleRand;
      expect(rand1, isNotNull);

      // Start a new trace
      hub.generateNewTrace();

      final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
      final rand2 = tx2.samplingDecision?.sampleRand;

      expect(rand2, isNotNull);
      expect(rand2, isNot(equals(rand1)));
    });
  });
}
