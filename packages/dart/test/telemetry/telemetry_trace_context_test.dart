import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/telemetry_trace_context.dart';
import 'package:test/test.dart';

import '../mocks/mock_sentry_client.dart';
import '../test_utils.dart';

void main() {
  group('resolveTelemetryTraceContext', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('uses the propagation context when no span is active', () {
      final hub = fixture.getSut();

      final context = resolveTelemetryTraceContext(hub);

      expect(context.traceId, hub.scope.propagationContext.traceId);
      expect(context.spanId, isNull);
    });

    test('uses the innermost streaming span', () async {
      final hub = fixture.getSut();

      await hub.startSpan('parent', (_) async {
        await hub.startSpan('child', (child) async {
          final context = resolveTelemetryTraceContext(hub);

          expect(context.traceId, child.traceId);
          expect(context.spanId, child.spanId);
        });
      });
    });

    test('uses the active idle span', () {
      final hub = fixture.getSut();
      final span = hub.startIdleSpan('idle');
      addTearDown(span.end);

      final context = resolveTelemetryTraceContext(hub);

      expect(context.traceId, span.traceId);
      expect(context.spanId, span.spanId);
    });

    test('uses the transaction bound to the scope', () {
      final hub = fixture.getSut(traceLifecycle: SentryTraceLifecycle.static);
      final transaction = hub.startTransaction('name', 'op', bindToScope: true);
      addTearDown(transaction.finish);

      final context = resolveTelemetryTraceContext(hub);

      expect(context.traceId, transaction.context.traceId);
      expect(context.spanId, transaction.context.spanId);
    });
  });
}

class Fixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;

  Hub getSut({
    SentryTraceLifecycle traceLifecycle = SentryTraceLifecycle.stream,
  }) {
    options.traceLifecycle = traceLifecycle;
    return Hub(options)..bindClient(MockSentryClient());
  }
}
