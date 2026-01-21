import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/default_metrics.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('$DefaultSentryMetrics', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when calling count', () {
      test('creates counter metric with correct type', () {
        fixture.sut.count('test-counter', 5);

        expect(fixture.capturedMetrics.length, 1);
        final metric = fixture.capturedMetrics.first;
        expect(metric, isA<SentryCounterMetric>());
        expect(metric.type, 'counter');
      });

      test('sets name and value', () {
        fixture.sut.count('my-counter', 42);

        final metric = fixture.capturedMetrics.first;
        expect(metric.name, 'my-counter');
        expect(metric.value, 42);
      });

      test('includes attributes when provided', () {
        fixture.sut.count(
          'test-counter',
          1,
          attributes: {'key': SentryAttribute.string('value')},
        );

        final metric = fixture.capturedMetrics.first;
        expect(metric.attributes['key']?.value, 'value');
      });

      test('sets trace id from scope', () {
        fixture.sut.count('test-counter', 1);

        final metric = fixture.capturedMetrics.first;
        expect(metric.traceId, fixture.scope.propagationContext.traceId);
      });

      test('sets timestamp from clock', () {
        fixture.sut.count('test-counter', 1);

        final metric = fixture.capturedMetrics.first;
        expect(metric.timestamp, fixture.fixedTimestamp);
      });
    });

    group('when calling gauge', () {
      test('creates gauge metric with correct type', () {
        fixture.sut.gauge('test-gauge', 42.5);

        expect(fixture.capturedMetrics.length, 1);
        final metric = fixture.capturedMetrics.first;
        expect(metric, isA<SentryGaugeMetric>());
        expect(metric.type, 'gauge');
      });

      test('sets name and value', () {
        fixture.sut.gauge('memory-usage', 75.5);

        final metric = fixture.capturedMetrics.first;
        expect(metric.name, 'memory-usage');
        expect(metric.value, 75.5);
      });

      test('includes unit when provided', () {
        fixture.sut.gauge('response-time', 250, unit: 'millisecond');

        final metric = fixture.capturedMetrics.first;
        expect(metric.unit, 'millisecond');
      });

      test('includes attributes when provided', () {
        fixture.sut.gauge(
          'test-gauge',
          10,
          attributes: {'env': SentryAttribute.string('prod')},
        );

        final metric = fixture.capturedMetrics.first;
        expect(metric.attributes['env']?.value, 'prod');
      });
    });

    group('when calling distribution', () {
      test('creates distribution metric with correct type', () {
        fixture.sut.distribution('test-distribution', 100);

        expect(fixture.capturedMetrics.length, 1);
        final metric = fixture.capturedMetrics.first;
        expect(metric, isA<SentryDistributionMetric>());
        expect(metric.type, 'distribution');
      });

      test('sets name and value', () {
        fixture.sut.distribution('response-time', 250);

        final metric = fixture.capturedMetrics.first;
        expect(metric.name, 'response-time');
        expect(metric.value, 250);
      });

      test('includes unit when provided', () {
        fixture.sut.distribution('response-time', 250, unit: 'millisecond');

        final metric = fixture.capturedMetrics.first;
        expect(metric.unit, 'millisecond');
      });

      test('includes attributes when provided', () {
        fixture.sut.distribution(
          'test-distribution',
          50,
          attributes: {'route': SentryAttribute.string('/api/users')},
        );

        final metric = fixture.capturedMetrics.first;
        expect(metric.attributes['route']?.value, '/api/users');
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final capturedMetrics = <SentryMetric>[];
  final fixedTimestamp = DateTime.utc(2024, 1, 15, 10, 30, 0);

  late final Scope scope;
  late final DefaultSentryMetrics sut;

  Fixture() {
    scope = Scope(options);
    sut = DefaultSentryMetrics(
      captureMetricCallback: (metric) async => capturedMetrics.add(metric),
      clockProvider: () => fixedTimestamp,
      defaultScopeProvider: () => scope,
    );
  }
}
