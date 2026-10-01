import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/default_metrics.dart';
import 'package:sentry/src/telemetry/metric/metrics_setup_integration.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';
import '../../mocks/mock_sentry_client.dart';

void main() {
  group('$MetricsSetupIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('configures DefaultSentryMetrics', () {
      fixture.sut.call(fixture.hub, fixture.options);

      expect(fixture.options.metrics, isA<DefaultSentryMetrics>());
    });

    test('correlates metrics with the active streaming span', () async {
      fixture.options.tracesSampleRate = 1.0;
      fixture.sut.call(fixture.hub, fixture.options);

      await fixture.hub.startSpan('parent', (span) async {
        fixture.options.metrics.count('count', 1);
        fixture.options.metrics.gauge('gauge', 2);
        fixture.options.metrics.distribution('distribution', 3);
        await Future<void>.delayed(Duration.zero);

        final metrics = fixture.client.captureMetricCalls.map(
          (call) => call.metric,
        );
        expect(metrics, hasLength(3));
        for (final metric in metrics) {
          expect(metric.traceId, span.traceId);
          expect(metric.spanId, span.spanId);
        }
      });
    });

    test('adds integration to SDK', () {
      fixture.sut.call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations,
        contains(MetricsSetupIntegration.integrationName),
      );
    });

    test('does not override existing non-noop metrics', () {
      final customMetrics = _CustomSentryMetrics();
      fixture.options.metrics = customMetrics;

      fixture.sut.call(fixture.hub, fixture.options);

      expect(fixture.options.metrics, same(customMetrics));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final client = MockSentryClient();

  late final Hub hub;
  late final MetricsSetupIntegration sut;

  Fixture() {
    hub = Hub(options)..bindClient(client);
    sut = MetricsSetupIntegration();
  }
}

class _CustomSentryMetrics implements SentryMetrics {
  @override
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {}

  @override
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {}

  @override
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {}
}
